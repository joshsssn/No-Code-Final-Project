// Teste les Code nodes "Read the message" de WF1 et WF4 tels que deployes dans n8n.
// Usage : N8N_API_KEY=... node tests/parse-test.mjs
const KEY = process.env.N8N_API_KEY;
const BASE = 'http://localhost:5678/api/v1/workflows/';
const WF = { WF1: '2vu1P4DfRSB4YxOp', WF4: '5yvBg4c45Jf2vavL' };
const INPUTS = ['/plein', '/plein Créteil', '/plein Créteil diesel', '/alerte gazole 1,65 Créteil', '/alerte gazole abc', '/start a_gazole_165_94000', 'bonjour'];

async function getCode(id) {
  const wf = await (await fetch(BASE + id, { headers: { 'X-N8N-API-KEY': KEY } })).json();
  return wf.nodes.find(n => n.name === 'Read the message').parameters.jsCode;
}

function run(code, text) {
  const $input = { first: () => ({ json: { message: { chat: { id: 42 }, from: { id: 42 }, text } } }) };
  return new Function('$input', code)($input)[0].json;
}

for (const [label, id] of Object.entries(WF)) {
  const code = await getCode(id);
  console.log('\n=== ' + label + ' Read the message ===');
  for (const t of INPUTS) {
    const o = run(code, t);
    const pick = label === 'WF1'
      ? { command: o.command, place: o.place, fuel: o.fuel, valid: o.valid }
      : { command: o.command, source: o.source, fuel: o.fuel, threshold: o.threshold, threshold_ok: o.threshold_ok, place: o.place };
    console.log(JSON.stringify(t).padEnd(32), JSON.stringify(pick));
  }
}
