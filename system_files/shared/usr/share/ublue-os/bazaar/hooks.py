# See https://github.com/bazaar-org/bazaar/blob/main/docs/overview.md#hooks

import os
import sys

# ---

unix_timestamp      = os.getenv('BAZAAR_HOOK_INITIATED_UNIX_STAMP')
unix_timestamp_usec = os.getenv('BAZAAR_HOOK_INITIATED_UNIX_STAMP_USEC')

hook_id            = os.getenv('BAZAAR_HOOK_ID')
hook_type          = os.getenv('BAZAAR_HOOK_TYPE')
was_aborted        = os.getenv('BAZAAR_HOOK_WAS_ABORTED')
dialog_id          = os.getenv('BAZAAR_HOOK_DIALOG_ID')
dialog_response_id = os.getenv('BAZAAR_HOOK_DIALOG_RESPONSE_ID')

non_transaction_appid = os.getenv('BAZAAR_APPID')
transaction_appid     = os.getenv('BAZAAR_TS_APPID')
transaction_type      = os.getenv('BAZAAR_TS_TYPE')

stage     = os.getenv('BAZAAR_HOOK_STAGE')
stage_idx = os.getenv('BAZAAR_HOOK_STAGE_IDX')

# ---

ALLOWED_HOOK_ACTIONS = {
    'install-jetbrains-toolbox',
    'install-vscode',
    'install-vscodium',
}

def log_child_error(message):
    log_path = os.path.join(os.getenv('XDG_STATE_HOME', os.path.expanduser('~/.local/state')), 'bazaar-hook.log')
    try:
        os.makedirs(os.path.dirname(log_path), exist_ok=True)
        with open(log_path, 'a', encoding='utf-8') as log_file:
            log_file.write(f'{message}\n')
    except OSError:
        pass

def detach_child():
    pid = os.fork()
    if pid != 0:
        return False

    os.setsid()
    with open(os.devnull, "rb", buffering=0) as devnull_in:
        os.dup2(devnull_in.fileno(), 0)

    return True

def spawn_hook_action(action):
    if action not in ALLOWED_HOOK_ACTIONS:
        raise ValueError(f"Refusing unsupported Bazaar hook action: {action}")

    if not detach_child():
        return

    try:
        os.execl(
            "/usr/bin/xdg-terminal-exec",
            "/usr/bin/xdg-terminal-exec",
            '--app-id=io.github.kolunmi.Bazaar',
            '--title=Bazaar',
            '--',
            'bash',
            '--noprofile',
            '--norc',
            '/usr/share/ublue-os/bazaar/run-hook-action',
            action,
        )
    except OSError as error:
        log_child_error(f"Failed to launch Bazaar hook action {action}: {error}")
        os._exit(127)

def log_action_error(action, error):
    print(f"Bazaar hook action failed for {action}: {error}", file=sys.stderr)

# ---

def handle_jetbrains():

    def appid_is_jetbrains(appid):
        return appid.startswith('com.jetbrains.') or appid == 'com.google.AndroidStudio'

    match stage:
        case 'setup':
            if transaction_type == 'install' and appid_is_jetbrains(transaction_appid):
                return 'ok'
            else:
                return 'pass'
        case 'setup-dialog':
            return 'ok'
        case 'teardown-dialog':
            if dialog_response_id == 'run-ujust':
                return 'ok'
            else:
                return 'abort'
        case 'catch':
            return 'abort'
        case 'action':
            try:
                spawn_hook_action('install-jetbrains-toolbox')
            except Exception as error:
                log_action_error('install-jetbrains-toolbox', error)
            return ''
        case 'teardown':
            return 'deny'

def handle_vscode():

    def appid_is_vscode(appid):
        return appid.startswith('com.visualstudio.code')

    match stage:
        case 'setup':
            if transaction_type == 'install' and appid_is_vscode(transaction_appid):
                return 'ok'
            else:
                return 'pass'
        case 'setup-dialog':
            return 'ok'
        case 'teardown-dialog':
            if dialog_response_id == 'run-brew':
                return 'ok'
            else:
                return 'abort'
        case 'catch':
            return 'abort'
        case 'action':
            try:
                spawn_hook_action('install-vscode')
            except Exception as error:
                log_action_error('visual-studio-code-linux', error)
            return ''
        case 'teardown':
            return 'deny'

def handle_vscodium():

    def appid_is_vscodium(appid):
        return appid.startswith('com.vscodium.codium')

    match stage:
        case 'setup':
            if transaction_type == 'install' and appid_is_vscodium(transaction_appid):
                return 'ok'
            else:
                return 'pass'
        case 'setup-dialog':
            return 'ok'
        case 'teardown-dialog':
            if dialog_response_id == 'run-brew':
                return 'ok'
            else:
                return 'abort'
        case 'catch':
            return 'abort'
        case 'action':
            try:
                spawn_hook_action('install-vscodium')
            except Exception as error:
                log_action_error('vscodium-linux', error)
            return ''
        case 'teardown':
            return 'deny'

# ---

response = 'pass'
match hook_id:
    case 'jetbrains-toolbox':
        response = handle_jetbrains()
    case 'vscode':
        response = handle_vscode()
    case 'vscodium':
        response = handle_vscodium()

print(response)
sys.exit(0)
