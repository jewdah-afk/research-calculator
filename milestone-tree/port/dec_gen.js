// Random Decimal op cases from the game's bundled break_eternity (the behaviour the port must match).
// usage: node dec_gen.js N seed > dec_cases.txt   (one case per line: op|a|b|expected)
const Decimal=require(require('path').join(__dirname,'..','game-js','technical','break_eternity.js'));
const N=+process.argv[2]||2000; let s=+process.argv[3]||1;
const r=()=>{s=(s*16807)%2147483647;return (s-1)/2147483646};
const pick=a=>a[Math.floor(r()*a.length)];
function rnd(){ const u=r(); const sign=r()<0.15?-1:1;
  if(u<0.05) return new Decimal(0);
  if(u<0.065) return pick([new Decimal(NaN), Decimal.fromComponents_noNormalize(NaN,NaN,NaN), Decimal.fromComponents_noNormalize(1,0,NaN)]);
  if(u<0.12) return new Decimal(pick([1,2,10,0.5,3,1.5,100,1e15,9e15,1.8e308,-1,-2,0.1,1e-5]));
  if(u<0.4) return new Decimal(sign*Math.pow(10,(r()-0.3)*20));
  if(u<0.6) return new Decimal(sign*Math.pow(10,r()*15.9));
  if(u<0.82) return new Decimal((sign<0?'-':'')+'1e'+((r()<0.2?-1:1)*Math.pow(10,r()*15.9)));
  if(u<0.95) return new Decimal((sign<0?'-':'')+'e'+Math.pow(10,r()*15.9).toExponential(8)).abs().mul(sign);
  if(u<0.97) return new Decimal(sign*Infinity);
  if(u<0.98) return Decimal.fromComponents_noNormalize(sign,Infinity,Infinity);
  return new Decimal('ee'+Math.pow(10,r()*15.9)).mul(sign);
}
function ok(d){ return isNaN(d.mag)&&(d.layer===0||isNaN(d.layer)) ||  Number.isFinite(d.layer)&&!Number.isNaN(d.mag)&&(Number.isFinite(d.mag)||d.layer===1) || d===Decimal.dInf || (d.layer===Infinity&&d.mag===Infinity); }
function small(){ const u=r(); if(u<0.3) return new Decimal(pick([0.5,2,3,1.5,0.9,1.05,10,1e-3,0.25,-0.5,-2,1/3])); if(u<0.6) return new Decimal((r()-0.3)*10); return rnd(); }
const enc=d=>[d.sign,d.layer,d.mag].join(',');
const ops={add:2,sub:2,mul:2,div:2,pow:2,log:2,max:2,min:2,root:2,gte:2,gt:2,lte:2,lt:2,eq:2,cmp:2,
  log10:1,ln:1,log2:1,floor:1,ceil:1,round:1,sqrt:1,cbrt:1,neg:1,abs:1,recip:1,toNumber:1,slog:1,tetrate:2,exp:1};
const out=[];
for(let i=0;i<N;i++){ const op=pick(Object.keys(ops)); let a=rnd(); while(!ok(a)) a=rnd(); let b=(op==='pow'||op==='root'||op==='log'||op==='tetrate')?small():rnd();
  while(!ok(b)) b=rnd();
  if(op==='tetrate'){ b=new Decimal(Math.floor(r()*4)+r()*(r()<0.5?1:0)); }
  const ea=enc(a), eb=enc(b);
  let res; try{ res=ops[op]===2?a[op](b):a[op](); }catch(e){ res='ERR' }
  let rs; if(res instanceof Decimal) rs='D'+enc(res); else if(typeof res==='number') rs='N'+res; else rs='B'+res;
  out.push([op,ea,eb,rs].join('|'));
}
console.log(out.join('\n'));
