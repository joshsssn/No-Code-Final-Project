"""Fire a bot on demand with a saved Telegram test payload (no phone needed).

Usage:
    python tests/send_update.py rapido "/plein Créteil gazole"
    python tests/send_update.py razmo  "/alerte gazole 1,65 Créteil"
    python tests/send_update.py razmo  --payload tests/payloads/razmo_deeplink.json

It posts a Telegram "update" to the local production webhook of WF1 or WF4,
exactly like Telegram would, signed with the secret token n8n expects
(<workflow id>_<trigger node id>). The message is sent as the owner
(config.owner_chat_id), so the bot's reply arrives on the owner's phone.

Needs N8N_API_KEY (environment variable or .env) and the workflows to be active.
"""
import json, os, sys, time, urllib.request

N8N = 'http://localhost:5678'
WORKFLOWS = {'rapido': '2vu1P4DfRSB4YxOp', 'razmo': '5yvBg4c45Jf2vavL'}
CONFIG_TABLE = '5n1kBw38vfsApLF7'
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def api_key():
    if os.environ.get('N8N_API_KEY'):
        return os.environ['N8N_API_KEY']
    with open(os.path.join(ROOT, '.env'), encoding='utf-8') as f:
        for line in f:
            if line.startswith('N8N_API_KEY='):
                return line.split('=', 1)[1].strip()
    sys.exit('N8N_API_KEY not found (env var or .env)')


def get(path, key):
    req = urllib.request.Request(N8N + path, headers={'X-N8N-API-KEY': key})
    return json.load(urllib.request.urlopen(req))


def main():
    if len(sys.argv) < 3 or sys.argv[1] not in WORKFLOWS:
        sys.exit(__doc__)
    bot, key = sys.argv[1], api_key()
    wf = get('/api/v1/workflows/' + WORKFLOWS[bot], key)
    trigger = next(n for n in wf['nodes'] if n['type'] == 'n8n-nodes-base.telegramTrigger')
    rows = get('/api/v1/data-tables/%s/rows' % CONFIG_TABLE, key)['data']
    owner = next((r['value'] for r in rows if r['key'] == 'owner_chat_id'), '') or '0'

    if sys.argv[2] == '--payload':
        update = json.load(open(sys.argv[3], encoding='utf-8'))
    else:
        update = {'update_id': int(time.time()), 'message': {
            'message_id': 1, 'date': int(time.time()), 'text': sys.argv[2],
            'from': {'id': 0, 'is_bot': False, 'first_name': 'Test'},
            'chat': {'id': 0, 'type': 'private'}}}
    update['message']['from']['id'] = int(owner)
    update['message']['chat']['id'] = int(owner)

    secret = ''.join(c for c in '%s_%s' % (wf['id'], trigger['id']) if c.isalnum() or c in '_-')
    req = urllib.request.Request(
        '%s/webhook/%s/webhook' % (N8N, trigger['webhookId']), data=json.dumps(update).encode(), method='POST',
        headers={'Content-Type': 'application/json', 'X-Telegram-Bot-Api-Secret-Token': secret})
    status = urllib.request.urlopen(req).status
    print('%s <- %r : HTTP %s' % (bot, update['message']['text'], status))


if __name__ == '__main__':
    main()
