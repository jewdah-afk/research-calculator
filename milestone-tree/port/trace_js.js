const fs=require('fs'),vm=require('vm');const states=JSON.parse(fs.readFileSync(process.argv[2]));const i=+process.argv[3];const st=states[i];const expr=process.argv[4];
const G=require('./jsgame')({resume:{seed:st.seed,now:1.7e12,player:st.save},extra:[__dirname+'/dump.js'],timeout:4000});const c=G.ctx;
console.log('load', vm.runInContext(expr,c));
for(const a of st.acts){ c.__acts=[a]; vm.runInContext('__act(__acts)',c,{timeout:3000}); console.log(JSON.stringify(a), vm.runInContext(expr,c)); }
