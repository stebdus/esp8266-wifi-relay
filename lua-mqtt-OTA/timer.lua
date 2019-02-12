local timer={}local a,b,c,d={},{},{},{}local e,g=2,false;timer.enable=false;timer.id=6;
local function h(i,j)local k,l=0,#i;for m=1,l do local n,o=false,m-k;if type(j)=='function'then n=j(i[o])else n=i[o]==j end;if i[o]~=nil and n then i[o]=nil;table.remove(i,o)k=k+1 end end;return i end;
local function p()if g then return else g=true end;local q;for m,r in ipairs(d)do r.delay=r.delay-e;if r.delay<=e then table.insert(c,r)d=h(d,r)end end;
for m=1,#a do table.insert(b,a[m])end;h(a,function(s)return s~=nil end)if#b>0 then for m,t in ipairs(b)do local u,v=pcall(t.f,unpack(t.args))if not u then print("Task execution fails: "..tostring(v))end end;
h(b,function(s)return s~=nil end)elseif#c>0 then q=c[1]table.remove(c,1)elseif#d==0 then tmr.stop(timer.id)timer.enable=false end;
if q~=nil then if q.rp>0 then q.delay=q.rp;if q.delay<=e then table.insert(c,q)else table.insert(d,q)end end;local u,v=pcall(q.f,unpack(q.args))if not u then print("Task execution fails: "..tostring(v))end end;
g=false end;function timer.start()tmr.alarm(timer.id,2,1,p)timer.enable=true end;function timer.stop()tmr.stop(timer.id)timer.enable=false;
a=h(a,function(s)return s~=nil end)b=h(b,function(s)return s~=nil end)c=h(c,function(s)return s~=nil end)d=h(d,function(s)return s~=nil end)end;
function timer.set(w)if w~=timer.id then timer.stop()timer.id=w;timer.start()end end;function timer.setImmediate(x,...)local q={delay=0,f=x,rp=0,args={...}}table.insert(a,q)if timer.enable==false then timer.start()end;
return q end;function timer.setTimeout(x,delay,...)local q={delay=delay,f=x,rp=0,args={...}}if delay<=e or delay>2147483646 then q.delay=e;table.insert(c,q)else table.insert(d,q)end;
if timer.enable==false then timer.start()end;return q end;function timer.setInterval(x,delay,...)local q=timer.setTimeout(x,delay,...)q.rp=delay;if timer.enable==false then timer.start()end;return q end;
function timer.clearImmediate(q)a=h(a,q)b=h(b,q)end;function timer.clearTimeout(q)h(c,q)h(d,q)end;timer.clearInterval=timer.clearTimeout;return timer
