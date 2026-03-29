#!/bin/python

import fcntl, json, os, re, shlex, subprocess, sys, tempfile, urllib.request
from contextlib import suppress

def bash(arguments):
  def trim(data, head = 2048, tail = 8192):
    if len(data) > head + tail:
      head = re.sub(rb'[^\n]*$', b'', data[:head])
      tail = re.sub(rb'^[^\n]*', b'', data[-tail:])
      skip = len(data) - len(head) - len(tail)
      data = head + f'[{skip} bytes suppressed]'.encode('utf-8') + tail
    with suppress(UnicodeError):
      if b'\0' not in data:
        return data.decode('utf-8')
    return '[Binary output suppressed]'

  with suppress(Exception):
    arguments = json.loads(arguments)
    try:
      sandbox = shlex.split(os.environ.get('SANDBOX', ''))
      command = [*sandbox, 'bash', '-c', arguments['command']]
      process = subprocess.run(command, capture_output = True,
        stdin = subprocess.DEVNULL, timeout = arguments.get('timeout'))
    except subprocess.TimeoutExpired as error:
      process =  subprocess.CompletedProcess(error.cmd, 124,
        error.stdout, error.stderr)
    return json.dumps({
      'status': process.returncode,
      'stdout': trim(process.stdout),
      'stderr': trim(process.stderr)
    })
  return json.dumps({
    'error': { 'message': 'Invalid arguments' }
  })

bash.schema = {
  'type': 'function',
  'name': 'bash',
  'description': 'Run a bash command or multi-line script',
  'parameters': {
    'type': 'object',
    'properties': {
      'command': { 'type': 'string' },
      'timeout': { 'type': 'number' }
    },
    'required': ['command']
  }
}

def die(status, *args):
  print(*args, file = sys.stderr, sep = ': ')
  sys.exit(status)

def generate(input, tools):
  for config in ['API', 'KEY', 'MODEL']:
    if config not in os.environ:
      die(1, f'{config} is missing in the environment')

  request = urllib.request.Request(os.environ['API'], json.dumps({
    'model': os.environ['MODEL'],
    'input': input,
    'store': False,
    'stream': True,
    'plugins': [ { 'id': 'web', 'engine': 'native' } ],
    'reasoning': { 'enabled': True },
    'tools': [tools[id].schema for id in tools]
  }).encode('utf-8'), {
    'Authorization': f'Bearer {os.environ['KEY']}',
    'Content-Type': 'application/json'
  })

  for chunk in stream(request):
    with suppress(KeyError, TypeError):
      die(1, chunk['error']['message'])
    with suppress(KeyError, TypeError):
      match chunk['type']:
        case 'response.output_text.delta':
          if delta := chunk['delta']:
            print(delta, end = '', flush = True)
        case 'response.output_text.done':
          if chunk['text']:
            print(end = '\n\n', flush = True)
        case 'response.content_part.done':
          for annotation in chunk['part']['annotations']:
            with suppress(KeyError, TypeError):
              print('Reference:', annotation['url'], end = '\n\n')
        case 'response.output_item.done':
          yield chunk['item']
        case 'response.incomplete':
          if reason := chunk['response']['incomplete_details']['reason']:
            print('Truncated:', reason, end = '\n\n')

def register(name, path):
  def run(arguments):
    process = subprocess.run([path], capture_output = True, check = True,
      encoding = 'utf-8', input = arguments)
    return process.stdout.removesuffix('\n')
  run.schema = { **json.loads(run('')), 'name': name }
  return run

def solicit():
  try:
    if not sys.stdin.isatty():
      sys.stdin.reconfigure(encoding = 'utf-8', errors = 'strict')
      return sys.stdin.read().strip('\n')
    with tempfile.NamedTemporaryFile() as tmp:
      editor = shlex.split(os.environ.get('EDITOR') or 'vi')
      subprocess.run([*editor, tmp.name], check = True)
      with open(tmp.name, 'r', encoding = 'utf-8') as tmp:
        text = tmp.read().strip('\n')
        if text and sys.stdout.isatty():
          print(f'\033[3m{text}\033[0m')
        return text
  except OSError as error:
    die(1, error.strerror)
  except UnicodeError:
    die(1, 'Invalid UTF-8 input')
  except ValueError:
    die(1, 'Malformed EDITOR')
  except subprocess.CalledProcessError:
    sys.exit(1)

def stream(request, timeout = 30):
  try:
    with urllib.request.urlopen(request, timeout = timeout) as stream:
      for line in stream:
        if line.startswith(b'data:'):
          with suppress(json.JSONDecodeError):
            yield json.loads(line[5:])
  except (OSError, urllib.error.URLError) as error:
    with suppress(Exception):
      if (body := json.load(error.fp))['error']['message']:
        yield body
    error = getattr(error, 'strerror', getattr(error, 'reason', str(error)))
    yield { 'error': { 'message': error } }

items, pending, tools = [], {}, { 'bash': bash }
sys.tracebacklimit = 0

match sys.argv[1:]:
  case ['agent'] | ['assistant'] | ['continue']:
    role, text = None, None
  case ['abort']:
    role, text = True, None
  case ['developer'] | ['system'] | ['user']:
    role, text = sys.argv[1], solicit()
  case _:
    die(64, f'Usage: {os.path.basename(sys.argv[0])} ROLE')

try:
  path = os.environ.setdefault('LOG', 'ua.log')
  log = open(path, 'a+', encoding = 'utf-8')
  fcntl.flock(log, fcntl.LOCK_EX | fcntl.LOCK_NB)
  log.seek(0)
except OSError as error:
  die(1, path, error.strerror)

try:
  for item in log:
    if item := item.strip():
      items.append(json.loads(item))
except Exception:
  die(1, log.name, 'Invalid NDJSON log file')

for item in items:
  with suppress(KeyError, TypeError):
    if item['type'] == 'function_call':
      pending[item['call_id']] = item
    if item['type'] == 'function_call_output':
      del pending[item['call_id']]

if role:
  for id in pending:
    print(json.dumps({
      'type': 'function_call_output', 'call_id': id,
      'output': '{ "error": { "message": "Function call aborted" } }'
    }), file = log, flush = True)
  if text:
    print(json.dumps({ 'type': 'message', 'role': role, 'content': text }),
      file = log, flush = True)
  sys.exit(0)

with suppress(KeyError, OSError):
  for tool in os.listdir(dir := os.environ['TOOLS']):
    with suppress(Exception):
      tools[tool] = register(tool, os.path.join(dir, tool))

while True:
  for id, call in pending.items():
    result = {
      'type': 'function_call_output', 'call_id': id,
      'output': '{ "error": { "message": "Invalid function call" } }'
    }
    with suppress(Exception):
      name, arguments = call['name'], call['arguments']
      if arguments and isinstance(arguments, str):
        result['output'] = tools[name](arguments)
    print(json.dumps(result), file = log, flush = True)
    items.append(result)
  pending.clear()

  if not items or items[-1].get('role') == 'assistant' \
      or items[-1].get('type') == 'reasoning':
    break

  for item in generate(items, tools):
    with suppress(KeyError, TypeError):
      if item['type'] == 'function_call':
        pending[item['call_id']] = item
      print(json.dumps(item), file = log, flush = True)
      items.append(item)
