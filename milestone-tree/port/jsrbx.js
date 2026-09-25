// Loads the original JS game the way a Roblox game instance runs it (game + stubs + rbx/session + rbx/view), headless,
// with the same deterministic random + clock as jsgame.js.
const vm=require('vm'),fs=require('fs'),path=require('path');
const R=(process.env.GAME_JS||path.join(__dirname,'..','game-js'))+'/';
module.exports=function load(){
  const files=JSON.parse(fs.readFileSync(__dirname+'/files.json'));
  let seed=12345; const rnd=()=>{seed=(seed*1103515245+12345)%2147483648;return seed/2147483648};
  const clock={now:1.7e12}; const noop=()=>{};
  const ctx={console,document:{getElementById:()=>null,createElement:()=>({style:{}}),body:{},addEventListener:noop,querySelector:()=>null,title:'',activeElement:{blur:noop}},
   window:{addEventListener:noop,location:{reload:noop},innerWidth:1280,innerHeight:720},localStorage:{getItem:()=>null,setItem:noop,removeItem:noop},
   Vue:{component:noop,prototype:{},set:(o,k,v)=>{o[k]=v}},setInterval:()=>0,setTimeout:()=>0,clearInterval:noop,
   alert:(m)=>{},confirm:()=>true,prompt:()=>null,btoa:s=>Buffer.from(s,'binary').toString('base64'),atob:s=>Buffer.from(s,'base64').toString('binary'),escape,unescape,encodeURIComponent,decodeURIComponent,navigator:{}};
  ctx.globalThis=ctx; vm.createContext(ctx);
  Object.assign(ctx,{__rnd:rnd,__now:()=>clock.now});
  vm.runInContext(`Math.random=()=>__rnd(); Date.now=()=>__now();`,ctx);
  for(const f of files) vm.runInContext(fs.readFileSync(R+f,'utf8'),ctx,{filename:f});
  for(const f of ['stubs.js','rbx/session.js','rbx/view.js']) vm.runInContext(fs.readFileSync(__dirname+'/'+f,'utf8'),ctx,{filename:f});
  return {ctx,clock,seed:s=>{seed=s},run:(code,t)=>vm.runInContext(code,ctx,{timeout:t||30000})};
};
