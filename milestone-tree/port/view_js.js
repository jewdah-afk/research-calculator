// JS side of the view parity test: node view_js.js states.json out.txt [from] [to]
// For every state: boot like the Roblox instance, dump the view of every shown layer (and each of its main tabs),
// then run the state's actions through rbx_do / rbx_tick and dump the current tab again.
const fs=require('fs');const states=JSON.parse(fs.readFileSync(process.argv[2]));
const out=[];const from=+process.argv[4]||0,to=+process.argv[5]||states.length;
const skip=new Set((process.env.SKIP||'').split(',').filter(x=>x).map(Number));
for(let i=from;i<to;i++){ if(skip.has(i)) continue; const st=states[i];
  const G=require('./jsrbx')(); G.seed(st.seed); G.ctx.__save=st.save;
  try{ G.run('rbx_boot(__save, "")'); }catch(e){ out.push('##S'+i+' BOOTERR '+String(e.message).slice(0,120)); continue; }
  G.run(fs.readFileSync(__dirname+'/view_dump.js','utf8')); G.ctx.__acts=st.acts;
  try{ out.push(G.run('rbx_viewDump("S'+i+'")')); }catch(e){ out.push('##S'+i+' DUMPERR '+String(e.message).slice(0,160)); }
  try{ out.push(G.run('rbx_viewActs("S'+i+'", __acts)')); }catch(e){ out.push('##S'+i+' ACTERR '+String(e.message).slice(0,160)); }
}
fs.writeFileSync(process.argv[3],out.join('\n')+'\n');
