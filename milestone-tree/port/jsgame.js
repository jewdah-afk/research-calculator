// Loads the original JS game headlessly (deterministic random + clock). Used by the timeline, profiler and diff runs.
const vm=require('vm'),fs=require('fs');
const R=(process.env.GAME_JS||require('path').join(__dirname,'..','game-js'))+'/';
module.exports=function load(opts={}){
  const files=JSON.parse(fs.readFileSync(__dirname+'/files.json'));
  let seed=12345; const rnd=()=>{seed=(seed*1103515245+12345)%2147483648;return seed/2147483648};
  const clock={now:1.7e12}; const noop=()=>{};
  const ctx={console,document:{getElementById:()=>null,createElement:()=>({style:{}}),body:{},addEventListener:noop,querySelector:()=>null,title:''},
   window:{addEventListener:noop,location:{reload:noop}},localStorage:{getItem:()=>null,setItem:noop,removeItem:noop},
   Vue:{component:noop,prototype:{},set:(o,k,v)=>{o[k]=v}},setInterval:()=>0,setTimeout:()=>0,clearInterval:noop,
   alert:(m)=>{console.error('ALERT',String(m).slice(0,200))},confirm:()=>true,prompt:()=>null,btoa:s=>Buffer.from(s,'binary').toString('base64'),atob:s=>Buffer.from(s,'base64').toString('binary'),escape,unescape,encodeURIComponent,decodeURIComponent,navigator:{}};
  ctx.globalThis=ctx; vm.createContext(ctx);
  Object.assign(ctx,{__rnd:rnd,__now:()=>clock.now});
  vm.runInContext(`Math.random=()=>__rnd(); Date.now=()=>__now();`,ctx);
  for(const f of files){ let s=fs.readFileSync(R+f,'utf8'); if(opts.patch) s=opts.patch(f,s); vm.runInContext(s,ctx,{filename:f}); }
  vm.runInContext(fs.readFileSync(__dirname+'/stubs.js','utf8'),ctx,{filename:'stubs.js'});
  for(const extra of (opts.extra||[])) vm.runInContext(fs.readFileSync(extra,'utf8'),ctx,{filename:extra});
  if(opts.resume){ const st=typeof opts.resume==='object'?opts.resume:JSON.parse(fs.readFileSync(opts.resume,'utf8')); seed=st.seed; clock.now=st.now; ctx.__RESUME=st.player; }
  vm.runInContext(fs.readFileSync(__dirname+'/boot.js','utf8'),ctx,{filename:'boot.js',...(opts.timeout?{timeout:opts.timeout}:{})});
  vm.runInContext(fs.readFileSync(opts.bot||__dirname+'/bot.js','utf8'),ctx,{filename:'bot.js'});
  return {ctx,clock,step(dt){clock.now+=dt*1000;ctx.__tick(dt)},
    save(path,extra){ fs.writeFileSync(path,JSON.stringify(Object.assign({seed,now:clock.now,player:vm.runInContext('JSON.stringify(player)',ctx)},extra||{}))); }};
};
