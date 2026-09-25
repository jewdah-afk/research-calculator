// FZ=<data dir> LUAU=<luau binary> node probe.js <state> [acts] 'expr1' 'expr2' ... : evaluate JS expressions after loading a fuzz state (and after the
// first [acts] actions) in both engines; the expressions are transpiled for the Luau side.
const fs=require('fs'),vm=require('vm'),{execFileSync}=require('child_process');const {transpile}=require('./js2lua');
const i=+process.argv[2]; const nacts=+process.argv[3]; const exprs=process.argv.slice(4);
const src='function __probe(){ var o=[]\n'+exprs.map(e=>'try { o.push(String('+e+')) } catch (err) { o.push("ERR "+err) }').join('\n')+'\nreturn o.join("\\n") }';
fs.writeFileSync(__dirname+'/gen/probe.luau','--!nocheck\nreturn function()\n'+transpile(src,'probe.js')+'\nend\n');
const DIR=process.env.FZ||'fz';const states=JSON.parse(fs.readFileSync(__dirname+'/data/'+DIR+'/states.json'));const st=states[i];
const G=require('./jsgame')({resume:{seed:st.seed,now:1.7e12,player:st.save},extra:[__dirname+'/dump.js'],timeout:60000});
vm.runInContext(src,G.ctx);
for(let k=0;k<nacts;k++){ G.ctx.__acts=[st.acts[k]]; vm.runInContext('__act(__acts)',G.ctx); }
const js=vm.runInContext('__probe()',G.ctx).split('\n');
const lua=execFileSync(process.env.LUAU||'luau',['-O2',__dirname+'/probe_run.luau','-a',String(i),String(nacts),DIR],{encoding:'utf8',timeout:120000}).trim().split('\n');
exprs.forEach((e,k)=>{ const same=js[k]===lua[k]; console.log((same?'  ':'≠ ')+e+'\n     js ='+js[k]+(same?'':'\n     lua='+lua[k])); });
