import fs from 'node:fs';
const wf = JSON.parse(fs.readFileSync('C:/WorkSpace/AIGame/tools/ImageWorkflows/krea2_t2i.json', 'utf8'));
console.log('top-level keys:', Object.keys(wf));
const nodes = wf.nodes || [];
for (const n of nodes) {
  console.log(`TOP id=${n.id} type=${n.type}`);
}
const defs = wf.definitions || (wf.extra && wf.extra.definitions);
if (defs && defs.subgraphs) {
  for (const sg of defs.subgraphs) {
    console.log('SUBGRAPH nodes:');
    for (const n of (sg.nodes||[])) {
      console.log(`  id=${n.id} type=${n.type} widgets=${JSON.stringify(n.widgets_values||[]).slice(0,220)}`);
      for (const inp of (n.inputs||[])) console.log(`     in: ${inp.name} = ${JSON.stringify(inp.value !== undefined ? inp.value : (inp.link ? 'link:'+inp.link : null))}`);
    }
  }
} else {
  console.log('no subgraphs; top nodes detail:');
  for (const n of nodes) {
    console.log(`  id=${n.id} type=${n.type} widgets=${JSON.stringify(n.widgets_values||[]).slice(0,220)}`);
  }
}
