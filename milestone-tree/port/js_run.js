// JS reference of run.luau: node js_run.js TICKS DT EVERY
const G=require('./jsgame')();const [T,DT,E]=[+process.argv[2]||2000,+process.argv[3]||0.05,+process.argv[4]||200];
const t0=Date.now();
for(let i=1;i<=T;i++){G.step(DT); if(i%E===0) console.log(G.ctx.__snap(i));}
console.log('-- '+(Date.now()-t0)/T+' ms/tick');
