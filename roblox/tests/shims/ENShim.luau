-- log-space big number shim: {s=sign, l=log10|abs|}
local EN = {}
local function N(x) if type(x)=="table" then return x end x=tonumber(x) or 0; if x==0 then return {s=0,l=-math.huge} end return {s=x<0 and -1 or 1, l=math.log10(math.abs(x))} end
local function add(a,b) a,b=N(a),N(b); if a.s==0 then return b end if b.s==0 then return a end
  if a.l<b.l then a,b=b,a end local d=b.l-a.l
  if a.s==b.s then return {s=a.s,l=a.l+math.log10(1+10^d)} end
  local r=1-10^d; if r<=1e-15 then return {s=0,l=-math.huge} end return {s=a.s,l=a.l+math.log10(r)} end
function EN.add(a,b) return add(a,b) end
function EN.sub(a,b) b=N(b); return add(a,{s=-b.s,l=b.l}) end
function EN.mul(a,b) a,b=N(a),N(b); if a.s==0 or b.s==0 then return N(0) end return {s=a.s*b.s,l=a.l+b.l} end
function EN.div(a,b) a,b=N(a),N(b); return {s=a.s*b.s,l=a.l-b.l} end
function EN.pow(a,b) a=N(a); b=type(b)=="table" and 10^b.l*b.s or b; if a.s==0 then return N(0) end return {s=1,l=a.l*b} end
local function cmp(a,b) a,b=N(a),N(b); local va=a.s==0 and -1e308 or a.s*a.l*(a.s); local A=(a.s==0) and -math.huge or (a.s>0 and a.l or -a.l); local B=(b.s==0) and -math.huge or (b.s>0 and b.l or -b.l)
  if a.s~=b.s then return (a.s<b.s) and -1 or 1 end if A==B then return 0 end if a.s>=0 then return A<B and -1 or 1 end return A<B and 1 or -1 end
function EN.me(a,b) return cmp(a,b)>0 end
function EN.meeq(a,b) return cmp(a,b)>=0 end
function EN.le(a,b) return cmp(a,b)<0 end
function EN.leeq(a,b) return cmp(a,b)<=0 end
function EN.log10(a) a=N(a); return a.l end
function EN.toScientific(a) a=N(a); if a.s==0 then return "0" end local e=math.floor(a.l); return (a.s<0 and "-" or "")..string.format("%.4fe%d",10^(a.l-e),e) end
function EN.short(a) return EN.toScientific(a) end
function EN.toString(a) return EN.toScientific(a) end
function EN.fromString(s) local neg,m,e=s:match("^(%-?)([%d%.]+)e(%-?%d+)$"); if not m then return N(tonumber(s) or 0) end return {s=neg=="-" and -1 or 1,l=math.log10(tonumber(m))+tonumber(e)} end
return EN
