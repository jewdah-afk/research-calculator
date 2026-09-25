// JS side of the differential test: node fuzz_js.js states.json out.txt [from] [to]
const fs=require('fs');const states=JSON.parse(fs.readFileSync(process.argv[2]));
const out=[];const from=+process.argv[4]||0,to=+process.argv[5]||states.length;
for(let i=from;i<to;i++){const st=states[i];
  let G;
  try{ G=require('./jsgame')({resume:{seed:st.seed,now:1.7e12,player:st.save},extra:[__dirname+'/dump.js'],timeout:(+process.env.FZ_TIMEOUT||2500)}); }
  catch(e){ out.push('##S'+i+' BOOTERR '+String(e.message).slice(0,120)); continue; }
  const c=G.ctx;
  try{ out.push(require('vm').runInContext("__dumpAll('S"+i+" load')",c,{timeout:(+process.env.FZ_TIMEOUT||2500)})); }catch(e){ out.push('##S'+i+' load DUMPERR '+e.message); }
  try{ c.__acts=st.acts; require('vm').runInContext('__act(__acts)',c,{timeout:(+process.env.FZ_TIMEOUT||2500)}); out.push(c.__dumpAll('S'+i+' acts')); }
  catch(e){ out.push('##S'+i+' acts '+(String(e.message).includes('timed out')?'HANG':'ERR '+String(e.message).slice(0,160))); }
}
fs.writeFileSync(process.argv[3],out.join('\n')+'\n');
