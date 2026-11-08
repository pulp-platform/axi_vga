#!/usr/bin/env python3
# Copyright 2026 CheshireAra contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Check public axi_vga display tests against transactions and RGB565 inputs."""
import sys
sys.dont_write_bytecode = True
import argparse
from collections import Counter, defaultdict, deque
import hashlib
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
TAG = re.compile(r'\[VGA_TEST_([A-Z_]+)\]\s*(.*)')
KEY = re.compile(r'(\w+)=([^\s]+)')
CASES = {'unit': {'timing': [901,902], 'flow': [903,904,905], 'restart': [906,907,908]}}
FORMAL = {'unit': {901:{1},902:{2},903:{3},904:{4},905:{6},906:{8},907:{10},908:{12}}}

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def integer(value, base=10):
    if value is None:
        return None
    try:
        return int(value, base)
    except (ValueError, TypeError):
        return None

class Audit:
    def __init__(self):
        self.errors=[];self.missing=[];self.details={};self.counts=Counter()
    def bad(self,name,message,**fields):
        self.counts['errors']+=1
        if len(self.errors)<2000:self.errors.append(dict(name=name,message=message,**fields))
    def lack(self,name,message,**fields):
        self.counts['missing']+=1
        if len(self.missing)<2000:self.missing.append(dict(name=name,message=message,**fields))
    def equal(self,name,actual,expected,**fields):
        self.counts['checks']+=1
        def unavailable(value):
            if value is None:return True
            if isinstance(value,(list,tuple)):return any(unavailable(item) for item in value)
            if isinstance(value,dict):return any(unavailable(item) for item in value.values())
            return False
        if unavailable(actual) or unavailable(expected):self.lack(name,'An actual value or input is unavailable',actual=actual,expected=expected,**fields)
        elif actual!=expected:self.bad(name,'Actual value differs from the independent input',actual=actual,expected=expected,**fields)
    def number(self,row,key,base=10,required=True):
        value=integer(row.get(key),base)
        if value is None and required:self.lack('raw_field','A required actual field is absent or unknown',field=key,raw=row.get(key),line=row.get('_line'))
        return value
    def finish(self):
        self.details['audit_counts']=dict(self.counts)
        for key in tuple(self.details):
            if key.startswith('_'):self.details.pop(key)
        return dict(passed=not self.counts['errors'] and not self.counts['missing'],observed_errors=self.errors,missing=self.missing,details=self.details)

def rows_from_text(text,audit):
    rows=[]
    for n,line in enumerate(text.splitlines(),1):
        if re.search(r'\bVGA_TEST_(?:ERROR|UNIT_FAIL)\b',line):audit.bad('original_error','Original VGA data reports an error',line=n,text=line)
        elif re.search(r'Fatal:|Fatal-\[|Error-\[|Assertion.*(?:fail|error)|started at .*failed at',line,re.I):audit.bad('simulator_error','Original simulator reports an error',line=n,text=line)
        if 'VGA_TEST_CONTROL_ERROR' in line:audit.lack('finite_control','The required stimulus did not complete',line=n,text=line)
        m=TAG.search(line)
        if not m:continue
        fields=KEY.findall(m[2]);r=dict(fields)
        if len(fields)!=len(r):audit.bad('raw_fields','Duplicate field in an observation',line=n)
        r.update(_kind=m[1],_line=n,_raw=line);rows.append(r)
    return rows


def pixel(i,epoch):
    return (((3*i+5*epoch+1)&31)<<11)|(((5*i+7*epoch+2)&63)<<5)|((11*i+3*epoch+4)&31)

def frame_window(epoch):
    guards=bytes((0xc7+29*epoch+49*j)&255 for j in range(32))
    image=b''.join(pixel(i,epoch).to_bytes(2,'little') for i in range(128))
    return guards[:16]+image+guards[16:]

def word(address,start,epoch):
    if address is None or start is None or epoch is None:return None
    offset=address-start
    if offset<0 or offset>=256 or offset%8:return None
    return sum(pixel(offset//2+j,epoch)<<(16*j) for j in range(4))

def finite_count(a,name,actual,expected,**fields):
    a.counts['checks']+=1
    if actual<expected:a.lack(name,'Finite observations are absent',actual=actual,expected=expected,**fields)
    elif actual>expected:a.bad(name,'Additional observations violate the finite contract',actual=actual,expected=expected,**fields)

def sequence(a,name,actual,expected):
    """Missing records do not change the identity of all following records."""
    available=list(expected)
    for value in actual:
        if value is None or isinstance(value,(tuple,list)) and any(x is None for x in value):a.lack(name,'A finite record identity is unknown',actual=value);continue
        if available and value==available[0]:available.pop(0)
        elif value in available:
            i=available.index(value)
            for absent in available[:i]:a.lack(name,'A finite record is absent',expected=absent)
            available=available[i+1:]
        else:a.bad(name,'An unexpected finite identity was observed',actual=value)
    for absent in available:a.lack(name,'A finite record is absent',expected=absent)

def expected_start(kind,cid):
    if cid is None:return None
    return 0x10010fff0 if cid==902 else 0x10fff0


def expected_config(kind,cid):
    positive=cid==902
    length=0 if cid == 902 else 15 if cid==904 else 7
    start=expected_start(kind,cid)
    return [6 if positive else 0,8,16,2,3,3,8,1,2,1,start&0xffffffff,start>>32,256,length]

def register_observations(rows,kind,a):
    values=[6,1]+[1]*8+[0]*4
    configs=[];mmio_count=0;write_order=[];read_order=[]
    for r in rows:
        if r['_kind']=='RESET':
            asserted=r.get('asserted')=='1'
            if asserted:values=[6,1]+[1]*8+[0]*4;write_order=[];read_order=[]
        if r['_kind'] != 'MMIO':continue
        mmio_count+=1;addr=a.number(r,'addr',16);write=a.number(r,'write',2);err=a.number(r,'error',2)
        if addr is None or write is None or err is None:continue
        a.equal('VGA_register_base',addr&~63,(0),line=r['_line'])
        index=(addr&63)//4
        if addr%4 or index>=14:a.bad('VGA_register_address','Unexpected VGA register access',address=addr,line=r['_line']);continue
        a.equal('VGA_register_error',err,0,line=r['_line'])
        if err:continue
        mask=7 if index==0 else 255 if index in (1,13) else 0xffffff if 2<=index<=9 else 0xffff if index==11 else 0xffffffff
        if write:
            strobe=a.number(r,'wstrb',16);data=a.number(r,'wdata',16)
            a.equal('VGA_register_strobe',strobe,15,line=r['_line'])
            if data is None:values[index]=None;continue
            values[index]=data&mask
            if index==0:write_order=[0];read_order=[]
            elif write_order==list(range(index)) and read_order==list(range(index)):write_order.append(index)
            else:write_order=[];read_order=[]
        else:
            a.equal('VGA_masked_readback',a.number(r,'rdata',16),values[index],offset=4*index,line=r['_line'])
            if write_order==list(range(index+1)) and read_order==list(range(index)):read_order.append(index)
            if read_order==list(range(14)) and all(v is not None for v in values):
                cid=integer(r.get('case'));expected=expected_config(kind,cid) if cid in FORMAL['unit'] else None
                if expected is not None:
                    a.equal('VGA_finite_configuration',values,expected,case=cid,line=r['_line']);configs.append((cid,integer(r.get('epoch'))));a.details.setdefault('_configuration_rows',[]).append(r)
    if not mmio_count:a.lack('VGA_MMIO','No accepted VGA register access exists')
    a.details['configurations']=configs
    return configs

class Raster:
    """Reference pixel schedule derived from reset, MMIO and the fixed divider."""
    def __init__(self):self.reset()
    def reset(self):
        self.control=6;self.divider=1;self.phase=0;self.running=False;self.h=0;self.v=0;self.frame=0
    def tick(self):return bool(self.control&1) and self.phase==0
    def sync(self):
        return (int(self.running and 18<=self.h<21) if self.control&2 else int(not(self.running and 18<=self.h<21)),
                int(self.running and 9<=self.v<11) if self.control&4 else int(not(self.running and 9<=self.v<11)))
    def visible(self):return self.running and self.h<16 and self.v<8
    def advance(self):
        if not self.control&1:self.running=False;self.h=0;self.v=0;self.frame=0
        elif self.tick():
            if not self.running:self.running=True;self.h=0;self.v=0;self.frame=0
            elif self.h==23:
                self.h=0
                if self.v==11:self.v=0;self.frame+=1
                else:self.v+=1
            else:self.h+=1
        self.phase=self.phase+1 if self.phase<(self.divider or 1)-1 else 0
    def write(self,offset,data):
        if data is None:return
        if offset==0:self.control=data&7
        if offset==4:self.divider=data&255

def pin_observations(rows,kind,profile,a):
    cycles=defaultdict(list);resets=[];changes=[]
    for r in rows:
        c=integer(r.get('cycle'))
        if c is not None and r['_kind'] in ('PIN','MMIO','AXI','AXI_UNUSED','CREDIT','FLOW'):cycles[c].append(r)
        if r['_kind']=='RESET' and (r.get('asserted')=='1' or r.get('event')=='assert'):
            t=integer(r.get('time_ps'))
            if t is not None:resets.append(t)
        if r['_kind']=='PIN_CHANGE':changes.append(r)
    model=Raster();last_cycle=None;last_time=None;coordinates={};formal=Counter();black=Counter();seen=Counter();reset_index=0;resets.sort();post_samples=[];stops=[]
    for c,group in sorted(cycles.items()):
        timing=[integer(r.get('time_ps')) for r in group if integer(r.get('time_ps')) is not None]
        t=min(timing) if timing else None
        if t is not None:
            while reset_index<len(resets) and resets[reset_index]<=t:
                if last_time is not None and model.control&1 and resets[reset_index]-last_time>5000:a.lack('pin_gap_before_reset','Active public-clock samples are missing before the actual reset',last_time_ps=last_time,reset_ps=resets[reset_index])
                model.reset();last_cycle=None;reset_index+=1
        if last_cycle is not None:
            gap=c-last_cycle
            if gap<1:a.bad('pin_cycle','Reference clock did not advance',cycle=c)
            if gap>1:
                # No enabled samples may disappear inside an active display.
                if model.control&1:a.lack('pin_cycle_gap','Active clock samples are absent',previous=last_cycle,actual=c)
                for unused in range(max(0,gap-1)):model.advance()
        pre=[r for r in group if r['_kind']=='PIN' and r.get('sample')=='pre'];post=[r for r in group if r['_kind']=='PIN' and r.get('sample')=='post']
        clock_time=integer(pre[0].get('time_ps')) if pre else integer(post[0].get('time_ps'))-1 if post and integer(post[0].get('time_ps')) is not None else t
        if last_cycle is not None and None not in (clock_time,last_time):a.equal('reference_clock_period',clock_time-last_time,(c-last_cycle)*5000,cycle=c)
        cid=next((integer(r.get('case')) for r in pre+post if integer(r.get('case')) is not None),None)
        epoch=next((integer(r.get('epoch')) for r in pre+post if integer(r.get('epoch')) is not None),None)
        coordinates[c]=dict(case=cid,epoch=epoch,frame=model.frame,h=model.h,v=model.v,tick=model.tick(),visible=model.visible(),running=model.running,time_ps=t)
        active=bool(model.control&1) or model.running
        if active and not pre:a.lack('pin_pre','Actual pre-update public pins are absent',cycle=c)
        if pre:finite_count(a,'pin_pre_count',len(pre),1,cycle=c)
        if post:finite_count(a,'pin_post_count',len(post),1,cycle=c)
        for r in pre:
            hs=a.number(r,'hsync',2);vs=a.number(r,'vsync',2)
            red=a.number(r,'red',16);green=a.number(r,'green',16);blue=a.number(r,'blue',16)
            rgb=None if None in (red,green,blue) else (red<<11)|(green<<5)|blue
            hgold,vgold=model.sync();a.equal('hsync_pre',hs,hgold,cycle=c);a.equal('vsync_pre',vs,vgold,cycle=c)
            if not model.visible():a.equal('blanking_pre',rgb,0,cycle=c)
            if model.tick() and model.visible():
                selected=epoch in FORMAL[kind].get(cid,set())
                target_frames=((1,2))
                if selected and model.frame in target_frames:
                    a.equal('RGB565_pixel',rgb,pixel(16*model.v+model.h,epoch),case=cid,epoch=epoch,frame=model.frame,x=model.h,y=model.v,cycle=c)
                    formal[(cid,epoch)]+=1
                if cid == 905 and epoch == 5 and (model.frame < 2):
                    a.equal('withheld_response_black',rgb,0,frame=model.frame,cycle=c);black[(cid,epoch)]+=1
            seen[(cid,epoch)]+=1
        model.advance()
        # Accepted MMIO takes effect after the old state has consumed this edge.
        for r in group:
            if r['_kind'] == 'MMIO' and integer(r.get('write'), 2) == 1 and (integer(r.get('error'), 2) == 0):
                addr=integer(r.get('addr'),16)
                if addr is not None:
                    data=integer(r.get('wdata'),16)
                    if (addr&63)==0 and data is not None and model.control&1 and not data&1:
                        stops.append(dict(case=integer(r.get('case')),epoch=integer(r.get('epoch')),cycle=c,h=model.h,v=model.v,frame=model.frame))
                    model.write(addr&63,data)

        if pre and (not post):a.lack('pin_post','Actual post-update public pins are absent',cycle=c)
        for r in post:
            hs=a.number(r,'hsync',2);vs=a.number(r,'vsync',2);hgold,vgold=model.sync()
            a.equal('hsync_post',hs,hgold,cycle=c);a.equal('vsync_post',vs,vgold,cycle=c)
            values=[a.number(r,k,16) for k in ('red','green','blue')]
            rgb=None if None in values else (values[0]<<11)|(values[1]<<5)|values[2]
            if not model.visible():a.equal('blanking_post',rgb,0,cycle=c)
            post_samples.append(r)
        last_cycle=c;last_time=clock_time
    expected=Counter((cid,next(iter(FORMAL[kind][cid]))) for cid in set(CASES[kind][profile]))
    for key in expected:finite_count(a,'formal_pixel_count',formal[key],256,case=key[0],epoch=key[1])
    if profile == 'flow':finite_count(a,'underflow_black_count',black[(905,5)],256)
    if not changes:a.lack('pin_changes','No public pin change stream exists')
    changes_at=defaultdict(list)
    for r in changes:
        t=a.number(r,'time_ps')
        if t is not None:changes_at[t].append(r)
        for f in ('hsync','vsync','red','green','blue'):a.number(r,f,2 if f.endswith('sync') else 16)
    fields=('hsync','vsync','red','green','blue');previous=None
    for sample in post_samples:
        t=integer(sample.get('time_ps'))
        if t is None:continue
        actual=tuple(integer(sample.get(f),2 if f.endswith('sync') else 16) for f in fields)
        updates=changes_at.get(t-1,[])+changes_at.get(t,[])
        if updates:
            last=updates[-1]
            final=tuple(integer(last.get(f),2 if f.endswith('sync') else 16) for f in fields)
            if None not in final:a.equal('pin_change_binding',final,actual,cycle=sample.get('cycle'))
        if previous is not None and previous[2:]==(sample.get('case'),sample.get('epoch')) and previous[1]!=actual and not updates:
            if not any(previous[0]<r<=t for r in resets):a.lack('pin_change_gap','A changed public post sample has no original change record',cycle=sample.get('cycle'))
        previous=(t,actual,sample.get('case'),sample.get('epoch'))
    allowed_changes={integer(r.get('time_ps')) for r in rows if r['_kind'] in ('PIN','MMIO') and integer(r.get('time_ps')) is not None}
    allowed_changes|={t for t in resets};allowed_changes|={t-1 for t in resets}
    for r in changes:
        t=integer(r.get('time_ps'))
        if t is not None and allowed_changes and min(allowed_changes)<=t<=max(allowed_changes) and t not in allowed_changes and t+1 not in allowed_changes:
            a.bad('pin_change_off_clock','A public output changed between reference-clock updates and reset events',time_ps=t,line=r['_line'])
    a.details['_raster_coordinates']=coordinates
    a.details['stop_positions']=stops
    a.details['formal_pixels']={str(k):v for k,v in formal.items()};a.details['underflow_black']={str(k):v for k,v in black.items()};a.details['pin_changes']=len(changes)
    return formal

def tagged_rows(rows):
    serial=0
    for row in rows:
        if row['_kind']=='RESET' and (row.get('asserted')=='1' or row.get('event')=='assert'):serial+=1
        yield serial,row


def axi_observations(rows,kind,profile,a):
    """Bind R to independent acceptance times, never to a shortened R list."""
    primary='external';streams=defaultdict(list);witness=defaultdict(dict);counts=Counter();vga_errors=[]
    accepted_ar=Counter();ar_stalls=Counter();inner_stalls=Counter();ledger={}
    for serial,row in tagged_rows(rows):
        cid=integer(row.get('case'));epoch=integer(row.get('epoch'));cycle=integer(row.get('cycle'))
        if row['_kind']=='AXI' and row.get('side') in (primary,'fetcher'):
            if cid is None or epoch is None:a.lack('AXI_identity','A public transaction has an unknown case or epoch',line=row['_line'])
            streams[(serial,cid,epoch,row['side'])].append(row)
        elif row['_kind'] in ('CREDIT','FLOW'):
            for side in (primary,'fetcher'):
                key=(serial,cid,epoch,side)
                if cycle in witness[key]:a.bad('acceptance_witness_duplicate','An actual acceptance witness repeats a cycle',cycle=cycle,side=side)
                if cycle is None:a.lack('acceptance_witness_cycle','An actual acceptance witness lacks its clock index',line=row['_line'])
                else:witness[key][cycle]=row
    if not streams:a.lack('AXI_stream','No public VGA AXI observations exist')
    for key,stream in streams.items():
        serial,cid,epoch,side=key;wr=witness[key];ars={};responses={};held={};unknown_r=[];unknown_ar=[]
        for row in stream:
            ch=row.get('channel');valid=a.number(row,'valid',2);ready=a.number(row,'ready',2);cycle=integer(row.get('cycle'))
            if ch in ('AW','W','B'):
                a.equal('read_only_master',valid,0,channel=ch,line=row['_line']);continue
            if ch not in ('AR','R'):a.bad('AXI_channel','An unexpected public AXI channel was captured',channel=ch,line=row['_line']);continue
            fields=('id','addr','len','size','burst','cache','lock','prot','qos','region','user') if ch=='AR' else ('id','data','resp','last','user')
            if ch in held:
                prior=held.pop(ch);a.equal('AXI_VALID_hold',valid,1,channel=ch,line=row['_line'])
                for field in fields:
                    if field in prior or field in row:a.equal('AXI_field_hold',integer(row.get(field),16),integer(prior.get(field),16),field=field,channel=ch,line=row['_line'])
            if valid==1 and ready==0:
                held[ch]=row
                (ar_stalls if ch=='AR' else inner_stalls if side=='fetcher' else Counter())[(cid,epoch)]+=1
            if valid is None or (valid==1 and ready is None):
                (unknown_ar if ch=='AR' else unknown_r).append(cycle)
            if valid!=1 or ready!=1:continue
            target=ars if ch=='AR' else responses
            if cycle is None:a.lack('AXI_accept_cycle','A completed public transaction has no actual clock index',line=row['_line'])
            if cycle is not None and cycle in target:a.bad('AXI_duplicate_accept','Two channel accepts occupy one public cycle',side=side,channel=ch,cycle=cycle)
            if cycle is not None:target[cycle]=row
            if ch=='R':
                # Header correctness is independent of a missing earlier beat.
                a.equal('AXI_R_id',a.number(row,'id',16),0,line=row['_line'])
                response=a.number(row,'resp',16)
                if response is not None and response not in (0,2,3):a.bad('AXI_response','Unexpected completed response code',actual=response,line=row['_line'])
                if side==primary:a.equal('external_RLAST',a.number(row,'last',2),1,line=row['_line'])
                if response in (2, 3):a.bad('unexpected_VGA_error','A non-error profile returned a completed AXI error',resp=response,line=row['_line'])
        # A held request may be discarded by the explicitly selected reset.
        aborted=(cid,epoch) in ((905,5),(908,11))
        if held and not aborted:
            for channel in held:a.lack('AXI_stalled_tail','The captured stream ends with an unaccepted valid channel',channel=channel,side=side,case=cid,epoch=epoch)
        ar_cycles=set(ars);r_cycles=set(responses);w_ar=set();w_r=set();unknown_r_witness=[];ar_holes=[]
        for cycle,row in wr.items():
            arfield='ar_accept' if side==primary else (None)
            if arfield is not None:
                value=a.number(row,arfield,2)
                if value==1:w_ar.add(cycle)
                elif value is None:ar_holes.append(cycle)
            validfield='external_rvalid' if side==primary else 'logical_rvalid';readyfield='external_rready' if side==primary else 'logical_rready'
            valid=a.number(row,validfield,2);ready=a.number(row,readyfield,2,required=valid!=0)
            if valid==1 and ready==1:w_r.add(cycle)
            elif valid is None or valid==1 and ready is None:unknown_r_witness.append(cycle)
        if side == primary:
            for cycle in ar_cycles-w_ar:a.lack('AR_accept_witness','An accepted header lacks its independent acceptance witness',side=side,cycle=cycle)
            for cycle in w_ar-ar_cycles:a.lack('AR_capture','An independent acceptance has no complete public AR record',side=side,cycle=cycle)
        for cycle in r_cycles-w_r:a.lack('R_accept_witness','An accepted R lacks its independent acceptance witness',side=side,cycle=cycle)
        for cycle in w_r-r_cycles:a.lack('R_capture','An independent accepted R has no complete public R record',side=side,cycle=cycle)
        all_ar=sorted(ar_cycles|w_ar);all_r=sorted(r_cycles|w_r)
        # Unit capture has no second logical-AR acceptance witness. A removed
        # whole header can therefore only be classified as missing capture or
        # unsolicited logical data. It cannot shift every following RGB word.
        unit_logical_loss=side=='fetcher' and kind=='unit' and (bool(unknown_ar) or len(all_r)>sum(integer(r.get('len'),16)+1 for r in ars.values() if integer(r.get('len'),16) is not None))
        logical_trust_limit=None
        if unit_logical_loss:a.lack('logical_AR_capture','The unit logical AR stream does not establish all response ownership')
        headers=[];prefix=0;known_prefix=True
        for ordinal,cycle in enumerate(all_ar):
            row=ars.get(cycle);shadow=wr.get(cycle,{})
            address=a.number(row,'addr',16) if row else (None)
            length=a.number(row,'len',16) if row else (None)
            if row:
                for field,gold in (('id',0),('size',3),('burst',1),('cache',2)):
                    a.equal('AXI_AR_shape',a.number(row,field,16),gold,field=field,line=row['_line'])
                for field in ('lock','prot','qos','region','user'):
                    if field in row:a.equal('AXI_AR_zero_field',a.number(row,field,16),0,field=field,line=row['_line'])
            start=expected_start(kind,cid) if cid in FORMAL['unit'] else None
            if side==primary:
                if row:a.equal('external_single_beat',length,0,line=row['_line'])
                if address is not None and start is not None:
                    a.equal('external_address_range',start<=address<start+256 and address%8==0,True,line=row['_line'] if row else None)
                    if not ar_holes:a.equal('external_address_prefix',address,start+8*(ordinal%32),case=cid,epoch=epoch,cycle=cycle)
                accepted_ar[(serial,cycle)]+=1
            elif None not in (address,length,start):
                a.equal('logical_address_range',start<=address<start+256 and address%8==0,True,cycle=cycle)
                a.equal('logical_4KiB',(address&4095)+8*(length+1)<=4096,True,cycle=cycle)
                done=(address-start)//8;maximum=expected_config(kind,cid)[13]+1
                wanted=min(maximum,32-done,(4096-(address&4095))//8)-1
                a.equal('logical_burst_length',length,wanted,case=cid,epoch=epoch,cycle=cycle)
                if known_prefix:
                    wanted_address=start+8*(prefix%32)
                    if unit_logical_loss and address!=wanted_address:
                        logical_trust_limit=prefix;known_prefix=False
                        a.lack('logical_AR_prefix','A missing logical header prevents later ordinal attribution',cycle=cycle)
                    else:a.equal('logical_address_prefix',address,wanted_address,case=cid,epoch=epoch,cycle=cycle)
            if length is None:
                known_prefix=False;headers.append((row,None,None,cycle));break
            if address is None:
                # A missing single-beat header has one unknown address slot;
                # its observed acceptance still preserves following ordinals.
                if side==primary:length=0
                else:known_prefix=False
            headers.extend((row,None if address is None else address+8*j,j==length,cycle) for j in range(length+1))
            prefix+=length+1
        # Unknown header lengths or response witnesses give a barrier. Data
        # before the barrier remains checkable; later data is never shifted.
        unknown_header_cycle=next((h[3] for h in headers if h[1] is None and h[2] is None),None)
        expected_count=len(headers) if unknown_header_cycle is None and cid is not None and epoch is not None else None
        if expected_count is not None and not aborted and not unit_logical_loss:finite_count(a,'AXI_response_count',len(all_r),expected_count,case=cid,epoch=epoch,side=side)
        if unknown_header_cycle is not None:a.lack('R_header_alignment','An unknown AR length prevents later response attribution',case=cid,epoch=epoch,side=side)
        lost_unlocated=expected_count is not None and len(all_r)<expected_count and not aborted
        # A missing raw R is located exactly by its independent witness. If both streams
        # omit an acceptance there is no truthful identity for later payloads.
        if lost_unlocated:a.lack('R_unlocated_acceptance','Accepted response count is incomplete in both observations',case=cid,epoch=epoch,side=side)
        ambiguous={x for x in unknown_r+unknown_r_witness if x is not None and x not in r_cycles and x not in w_r}
        boundary=min(ambiguous,default=None)
        located_loss=expected_count is not None and expected_count-len(all_r)<=len(ambiguous)
        # Retain only a timing-proven prefix when both response captures have
        # a hole. Before the next accepted header, a single released slot has
        # a unique owner; response payload values never choose that slot.
        causal_prefix=0
        if lost_unlocated:
            for ordinal,cycle in enumerate(all_r):
                opaque=any(t is None or t<=cycle for t in unknown_ar+ar_holes)
                released=[h for h in headers if h[3]<=cycle]
                if opaque or len(released)!=ordinal+1 or any(h[2] is None for h in released):break
                causal_prefix=ordinal+1
        mapped=[]
        for ordinal,cycle in enumerate(all_r):
            row=responses.get(cycle)
            if row is None:continue
            trustworthy=(not lost_unlocated or ordinal<causal_prefix or located_loss and boundary is not None and cycle<boundary) and (boundary is None or cycle<boundary)
            if unit_logical_loss and logical_trust_limit is not None and ordinal>=logical_trust_limit:trustworthy=False
            if not trustworthy or ordinal>=len(headers):
                a.lack('R_attribution','This actual response cannot be assigned a unique request after missing inputs',side=side,cycle=cycle);continue
            request,address,last,request_cycle=headers[ordinal]
            if unknown_header_cycle is not None and (address is None or request_cycle>=unknown_header_cycle):a.lack('R_attribution','The actual request length/address is absent',side=side,cycle=cycle);continue
            a.equal('R_after_accepted_AR',cycle>=request_cycle,True,cycle=cycle,side=side)
            a.equal('AXI_RLAST',a.number(row,'last',2),None if last is None else int(last),line=row['_line'])
            response=a.number(row,'resp',16)
            if response==0:a.equal('AXI_RGB565_data',a.number(row,'data',16),word(address,expected_start(kind,cid),epoch),case=cid,epoch=epoch,side=side,line=row['_line'])
            if side==primary and response in (2,3):vga_errors.append(dict(case=cid,epoch=epoch,row=row,address=address,resp=response))
            mapped.append(dict(cycle=cycle,address=address,last=last,resp=response))
        # A completed error remains an error observation even when its request
        # cannot be mapped. Its unknown address becomes MISSING at the caller.
        for cycle,row in responses.items():
            response=integer(row.get('resp'),16)
            if side==primary and response in (2,3) and not any(x['row'] is row for x in vga_errors):vga_errors.append(dict(case=cid,epoch=epoch,row=row,address=None,resp=response))
        counts['accepted_'+side+'_AR']+=len(ars);counts['accepted_'+side+'_R']+=len(responses)
        ledger[key]=dict(ar_cycles=all_ar,r_cycles=all_r,headers=headers,mapped=mapped,complete=not unit_logical_loss and not lost_unlocated and not ambiguous and unknown_header_cycle is None)
    unused=[r for r in rows if r['_kind']=='AXI_UNUSED'];captured={(r.get('case'),r.get('epoch'),r.get('cycle')) for r in unused}
    for r in rows:
        if r['_kind']=='PIN' and r.get('sample')=='pre' and (r.get('case'),r.get('epoch'),r.get('cycle')) not in captured:a.lack('write_channel_sample','An active read-only channel sample is absent',case=r.get('case'),epoch=r.get('epoch'),cycle=r.get('cycle'))
    for r in unused:
        for field in ('aw_valid','w_valid','b_valid'):a.equal('read_only_master',a.number(r,field,2),0,field=field,line=r['_line'])
    credit_observations(rows,kind,profile,a,accepted_ar,ar_stalls,inner_stalls,{k[0] for k,v in ledger.items() if not v['complete']})

    a.details['actual_error_count']=len(vga_errors)
    a.details['AXI_counts']=dict(counts);a.details['_axi_ledger']=ledger
    return vga_errors


def credit_observations(rows,kind,profile,a,accepted_ar,ar_stalls,inner_stalls,uncertain_serials=None):
    credits=0;known=True;serial=0;maximum=0;full=Counter();seen=0;witnessed_ar=set();states={}
    captured={(n,integer(r.get('cycle'))) for n,r in tagged_rows(rows) if r['_kind'] in ('CREDIT','FLOW')}
    holes=defaultdict(list)
    for key,count in accepted_ar.items():
        if count and key not in captured:holes[key[0]].append(key[1])
    for n,r in tagged_rows(rows):
        if r['_kind']=='AXI' and r.get('side')=='fetcher' and r.get('channel')=='R' and r.get('valid')=='1' and r.get('ready')=='1' and (n,integer(r.get('cycle'))) not in captured:holes[n].append(integer(r.get('cycle')))
    first_hole={n:min(c for c in values if c is not None) for n,values in holes.items() if any(c is not None for c in values)}
    for row in rows:
        if row['_kind']=='RESET' and (row.get('asserted')=='1' or row.get('event')=='assert'):serial+=1;credits=0;known=True
        if row['_kind'] not in ('CREDIT','FLOW'):continue
        seen+=1;cycle=integer(row.get('cycle'))
        if uncertain_serials and serial in uncertain_serials:known=False
        if serial in first_hole and cycle is not None and cycle>=first_hole[serial]:known=False
        ar=a.number(row,'ar_accept',2);valid=a.number(row,'fifo_valid',2);ready=a.number(row,'fifo_ready',2,required=valid!=0);last=a.number(row,'fifo_last',2,required=valid==1 and ready==1)
        actual=accepted_ar[(serial,cycle)];witnessed_ar.add((serial,cycle))
        if actual!=ar:a.lack('credit_public_AR','Two acceptance captures are incomplete or disagree',actual=actual,witness=ar,cycle=cycle);known=False
        pop=valid==1 and ready==1 and last==1
        if ar is None or valid is None or valid==1 and ready is None or valid==1 and ready==1 and last is None:known=False
        if not known:states[(serial,cycle)]=None;continue
        before=credits
        if before==16 and not pop:
            a.equal('credit_full_no_issue',ar,0,cycle=cycle)
            if row.get('split_ar_valid')=='1' and row.get('external_ar_valid')=='0':full[(integer(row.get('case')),integer(row.get('epoch')))]+=1
        credits+=ar-int(pop);maximum=max(maximum,credits);states[(serial,cycle)]=credits
        if not 0<=credits<=16:a.bad('credit_range','Accepted AR minus public FIFO RLAST pops exceeds0..16',actual=credits,cycle=cycle)
        if 'dut_actual' in row:a.equal('credit_actual_ff',a.number(row,'dut_actual'),before,cycle=cycle)
    for key,count in accepted_ar.items():
        if count and key not in witnessed_ar:a.lack('credit_missing_accept','A real AR has no complete credit event',serial=key[0],cycle=key[1]);known=False
    if not seen:a.lack('credit_observation','No actual response-FIFO acceptance stream exists')
    if profile == 'flow':
        if not ar_stalls[(903,3)]:a.lack('AR_backpressure','The required actual AR hold did not occur')
        if not inner_stalls[(904,4)]:a.lack('response_backpressure','The required actual fetcher R hold did not occur')
        if not full[(904,4)]:a.lack('credit_full','The required full-credit rejection did not occur')
    a.details['_credit_states']=states
    a.details['credit_max']=maximum;a.details['AR_stall_clocks']={str(k):v for k,v in ar_stalls.items()};a.details['fetcher_R_stall_clocks']={str(k):v for k,v in inner_stalls.items()}


def lifecycle_observations(rows,kind,profile,configurations,a):
    expected={'timing':[(901,1),(902,2)],'flow':[(903,3),(904,4),(905,5),(905,6)],'restart':[(906,7),(906,8),(907,9),(907,10),(908,11),(908,12)]}[profile]
    sequence(a,'finite_configuration_epochs',configurations,expected)
    aborted={(905,5),(908,11)};primary='external'
    drains=[r for r in rows if r['_kind']=='DRAIN'];sequence(a,'finite_drain_epochs',[(integer(r.get('case')),integer(r.get('epoch'))) for r in drains],[x for x in expected if x not in aborted])
    # AR/R counts come from the independently timed public acceptance ledger.
    # A missing raw R with a complete independent acceptance witness remains countable.
    ledger=a.details.get('_axi_ledger',{});credit_states=a.details.get('_credit_states',{});coords=a.details.get('_raster_coordinates',{})
    resets=[];serial=0;disable={};enable={};drained=set();gap_reports=[]
    for row in rows:
        tag=row['_kind'];case=integer(row.get('case'));epoch=integer(row.get('epoch'));identity=(case,epoch);cycle=integer(row.get('cycle'))
        if tag=='RESET' and (row.get('asserted')=='1' or row.get('event')=='assert'):
            resets.append(row);serial+=1
        if tag == 'MMIO' and integer(row.get('write'), 2) == 1 and (integer(row.get('error'), 2) == 0):
            address=integer(row.get('addr'),16);value=integer(row.get('wdata'),16)
            if address is not None and address&63==0 and value is not None:
                if value&1:enable[identity]=row
                elif identity in enable:disable[identity]=row
        if tag=='DRAIN':
            if identity not in disable:a.lack('disable_before_drain','No accepted enable-to-disable transition precedes this drain',case=case,epoch=epoch)
            values=[];trust=True
            for side in (primary,'fetcher'):
                state=ledger.get((serial,case,epoch,side))
                if state is None or not state['complete']:
                    a.lack('drain_public_state','Missing public requests/acceptances prevent a drain conclusion',case=case,epoch=epoch,side=side);trust=False;continue
                requests=[h for h in state['headers'] if cycle is not None and h[3]<=cycle]
                replies=[c for c in state['r_cycles'] if cycle is not None and c<=cycle]
                # Unknown length/address slots never serve as a zero balance.
                if any(h[1] is None for h in requests):a.lack('drain_request_address','A drained request lacks its actual address',side=side);trust=False
                else:a.equal('drained_public_requests',len(requests)-len(replies),0,case=case,epoch=epoch,side=side)
                values.extend((c for c in state['ar_cycles']+state['r_cycles'] if cycle is not None and c<=cycle))
            before=[(c,v) for (n,c),v in credit_states.items() if n==serial and c is not None and cycle is not None and c<=cycle]
            if not before or max(before)[1] is None:a.lack('drain_public_credit','The public FIFO pop/AR stream does not establish credit at drain',case=case,epoch=epoch);trust=False
            else:a.equal('drained_public_credit',max(before)[1],0,case=case,epoch=epoch)
            for field in ('actual_ar_valid','actual_r_valid'):
                if field in row:a.equal('drain_actual_channel_idle',a.number(row,field,2),0,field=field)

            if values and cycle is not None:a.equal('unit_drain64clock_quiet',cycle-max(values)>=64,True,case=case,epoch=epoch)
            else:a.lack('unit_drain_last_accept','The drain has no attributable public acceptance history',case=case,epoch=epoch)
            a.equal('unit_drain_reported_quiet',a.number(row,'quiet'),64)
            clocks=a.number(row,'clocks')
            if clocks is not None:a.equal('unit_drain_finite_budget',64<=clocks<=4096,True)
            if trust:drained.add(identity)
    # Each public reset assertion is paired with its actual release.
    for index,assertion in enumerate(resets):
        start=a.number(assertion,'time_ps');stop=None
        releases=[r for r in rows if r['_kind']=='RESET' and r.get('asserted')=='0' and integer(r.get('time_ps')) is not None and start is not None and integer(r['time_ps'])>start]
        if releases:stop=integer(releases[0]['time_ps'])
        a.equal('common_reset_five_clocks',None if stop is None or start is None else stop-start,25000,index=index)
    expected_resets=({'timing':2,'flow':4,'restart':4}[profile])
    finite_count(a,'common_reset_count',len(resets),expected_resets)
    if profile == 'restart':
        for case,epoch in ((906,7),(907,9)):
            positions=[r for r in a.details.get('stop_positions',[]) if (r['case'],r['epoch'])==(case,epoch)];finite_count(a,'selected_stop_position',len(positions),1,case=case)
            for pos in positions:
                a.equal('stop_vertical_position',pos['v'],8 if case==906 else 3,case=case);a.equal('stop_horizontal_position',pos['h'],0 if case==906 else 9,case=case)
                a.equal('stop_raster_frame',pos['frame'],4 if case==906 else 1,case=case)
        target=disable.get((907,9));stop_cycle=integer(target.get('cycle')) if target else None
        stream=[r for r in rows if r['_kind']=='AXI' and r.get('side')==primary and r.get('channel')=='R' and integer(r.get('case'))==907 and integer(r.get('epoch'))==9 and r.get('valid')=='1']
        accepts=sorted({integer(r.get('cycle')) for r in stream if r.get('ready')=='1' and integer(r.get('cycle')) is not None})
        gaps=[(x,y) for x,y in zip(accepts,accepts[1:]) if stop_cycle is not None and x<=stop_cycle+4 and y>=stop_cycle and y-x>=33]
        if not gaps:a.lack('selected_32clock_R_gap','No actual32-cycle response gap with pending old traffic is attributable to the stop')
        else:
            left,right=min(gaps,key=lambda p:abs(p[0]-stop_cycle));quiet=right-left-1
            # An already active R may be held until accepted; the32 empty
            # cycles begin after that actual acceptance, not at disable.
            a.equal('selected_32clock_RVALID_gap',quiet,32)
            busy=[r for r in rows if r['_kind']=='AXI' and r.get('side')==primary and r.get('channel')=='AR' and r.get('valid')=='1' and r.get('ready')=='1' and integer(r.get('case'))==907 and integer(r.get('epoch'))==9 and integer(r.get('cycle')) is not None and integer(r['cycle'])<=left]
            returned=[x for x in accepts if x<=left]
            a.equal('32clock_gap_with_pending_requests',len(busy)>len(returned),True)
            valid=[r for r in stream if integer(r.get('cycle')) is not None and left<integer(r.get('cycle'))<right]
            if valid:a.bad('32clock_gap_RVALID','A new RVALID was presented inside the selected empty response gap',cycles=[r['cycle'] for r in valid])
            gap_reports.append(dict(last_accepted=left,next_valid=right,empty_clocks=quiet))
        old=[r for r in resets if integer(r.get('case'))==908 and integer(r.get('epoch'))==11];finite_count(a,'unit_inflight_reset',len(old),1)
        for row in old:inflight_reset(rows,row,kind,a,ledger)
    if profile == 'flow':
        active=[c for c,p in coords.items() if (p['case'],p['epoch'])==(905,5) and p['running'] and p['frame']<2]
        if not active:a.lack('underflow_two_frame_window','No actual first-two-frame reference window exists')
        else:
            bad=[r for r in rows if r['_kind']=='AXI' and r.get('side')==primary and r.get('channel')=='R' and r.get('valid')=='1' and integer(r.get('cycle')) in active]
            if bad:a.bad('underflow_response_withheld','A real external RVALID appeared during the two withheld frames',line=bad[0]['_line'])


    a.details['lifecycle']=dict(configurations=configurations,drain_epochs=[(integer(r.get('case')),integer(r.get('epoch'))) for r in drains],common_resets=len(resets),response_gap=gap_reports)


def inflight_reset(rows,reset,kind,a,ledger):
    case=integer(reset.get('case'));epoch=integer(reset.get('epoch'));cycle=integer(reset.get('cycle'));time=integer(reset.get('time_ps'));primary='external'
    if cycle is None and time is not None:
        cycle=max((integer(r.get('cycle')) for r in rows if integer(r.get('cycle')) is not None and integer(r.get('time_ps')) is not None and integer(r['time_ps'])<time),default=None)
    candidates=[state for (serial,c,e,side),state in ledger.items() if (c,e,side)==(case,epoch,primary)]
    if len(candidates)!=1:a.lack('reset_inflight_public_stream','The old outstanding request stream is absent or ambiguous');return
    state=candidates[0];ar=[c for c in state['ar_cycles'] if cycle is not None and c<=cycle];rs=[c for c in state['r_cycles'] if cycle is not None and c<=cycle]
    if not state['complete']:a.lack('reset_inflight_public_state','Missing accepted transactions prevent an outstanding-prefix conclusion')
    else:a.equal('reset_old_request_outstanding',len(ar)>len(rs),True)
    a.equal('reset_before_any_old_R',len(rs),0)
    if ar:
        actual=[r for r in rows if r['_kind']=='AXI' and r.get('side')==primary and r.get('channel')=='AR' and r.get('valid')=='1' and r.get('ready')=='1' and integer(r.get('case'))==case and integer(r.get('epoch'))==epoch and integer(r.get('cycle'))==ar[0]]
        enables=[r for r in rows if r['_kind']=='MMIO' and integer(r.get('case'))==case and integer(r.get('epoch'))==epoch and r.get('write')=='1' and integer(r.get('addr'),16) is not None and integer(r['addr'],16)&63==0 and integer(r.get('wdata'),16) is not None and integer(r['wdata'],16)&1]
        if not actual or not enables:a.lack('inflight_reset_schedule','The first accepted AR or enabling register write lacks an actual timestamp')
        else:
            first=a.number(actual[0],'time_ps');enable=a.number(enables[-1],'time_ps')
            a.equal('first_AR_after_enable',None if first is None or enable is None else first>=enable,True)
            # First poll after observing AR is at the following negedge
            # +1ps; clocks(3), then reset_common adds one more negedge.
            first_poll=max(first,enable)+2501 if first is not None and enable is not None else None
            a.equal('reset_actual_source_schedule',time,None if first_poll is None else first_poll+4*5000)


def fault_observations(rows,kind,profile,errors,a):
    # Display profiles do not inject errors. Error-injection traces cannot be
    # mistaken for the normal public timing, flow or restart stimulus.
    for name,tag in (('arm','RERR_ARM'),('clear','RERR_CLEAR'),('after','RERR_AFTER')):
        finite_count(a,'external_rerr_'+name,sum(r['_kind']==tag for r in rows),0)
    external_errors=[r for r in rows if r['_kind']=='AXI' and r.get('side') not in ('external','fetcher') and r.get('channel')=='R' and r.get('valid')=='1' and r.get('ready')=='1' and integer(r.get('resp'),16) in (2,3)]
    finite_count(a,'external_error_count',len(external_errors),0)


def configuration_lifecycle(rows,kind,configurations,a):
    config_rows=a.details.get('_configuration_rows',[])
    for old,new in zip(config_rows,config_rows[1:]):
        old_id=(integer(old.get('case')),integer(old.get('epoch')));lo=old['_line'];hi=new['_line']
        drains=[r for r in rows if r['_kind']=='DRAIN' and (integer(r.get('case')),integer(r.get('epoch')))==old_id and lo<r['_line']<hi]
        resets=[r for r in rows if r['_kind']=='RESET' and (r.get('asserted')=='1' or r.get('event')=='assert') and lo<r['_line']<hi]
        if not drains and not resets:a.lack('configuration_after_drain_or_reset','The previous epoch has no real drain or common reset before reconfiguration',old_epoch=old_id,new_epoch=(new.get('case'),new.get('epoch')))
    by_cycle=defaultdict(list)
    for row in rows:
        cycle=integer(row.get('cycle'))
        if cycle is not None:by_cycle[cycle].append(row)
    enabled=False;known=True
    for cycle,group in sorted(by_cycle.items()):
        if any(r['_kind']=='RESET' and (r.get('asserted')=='1' or r.get('event')=='assert') for r in group):enabled=False;known=True
        for row in group:
            if row['_kind']=='AXI' and row.get('side')=='fetcher' and row.get('channel')=='AR' and row.get('valid')=='1' and known and not enabled:
                # Initial unit resets lack cycle fields. Their following
                # configure writes establish disabled state before any request.
                a.bad('logical_AR_after_disable','A new logical ARVALID was asserted with actual enable clear',line=row['_line'])
        for row in group:
            if row['_kind'] == 'MMIO' and row.get('write') == '1' and (row.get('error') == '0'):
                address=integer(row.get('addr'),16)
                if address is not None and address&63==0:
                    value=integer(row.get('wdata'),16);known=value is not None
                    if known:enabled=bool(value&1)


def verify_inputs(a):
    binding=HERE/'public_inputs.json'
    if not binding.is_file():a.lack('payload_binding','Public input binding is absent');return
    for name,want in json.loads(binding.read_text()).items():
        path=HERE/name
        if not path.is_file():a.lack('payload_file','A public input is absent',path=name)
        else:a.equal('public_input_SHA256',sha(path),want,path=name)


def completion_observations(text,rows,kind,profile,a):
    done=[r for r in rows if r['_kind']=='DONE'];finite_count(a,'done_count',len(done),1)
    if done:
        row=done[0];a.equal('DONE_kind',row.get('kind'),kind);a.equal('DONE_profile',row.get('profile'),profile);a.equal('reported_error_count',a.number(row,'errors'),0)
        actual=512 if profile=='timing' else 768
        a.equal('reported_formal_pixels',a.number(row,'formal_rgb'),actual)
        a.equal('reported_cases',a.number(row,'cases'),len(set(CASES[kind][profile])))
        a.equal('reported_black_pixels',a.number(row,'formal_black'),256 if profile=='flow' else 0)
        for field,name in (('ar','accepted_external_AR'),('r','accepted_external_R')):a.equal('reported_actual_AXI_count',a.number(row,field),a.details.get('AXI_counts',{}).get(name,0),field=field)
    marker=(r'^VGA_TEST_UNIT_PASS profile='+re.escape(profile)+r'\s*$')
    matches=list(re.finditer(marker,text,re.M));finite_count(a,'normal_success_marker',len(matches),1)
    finish=list(re.finditer(r'^\s*\$finish called from file[^\n]*',text,re.M));finite_count(a,'normal_finish',len(finish),1)
    stamps=list(re.finditer(r'^\s*\$finish at simulation time\s+(\d+)[^\n]*',text,re.M));finite_count(a,'normal_finish_time',len(stamps),1)
    if stamps:a.equal('positive_finish_time',int(stamps[0][1])>0,True)
    if matches and finish:a.equal('success_before_finish',matches[0].start()<finish[0].start(),True)
    if finish:
        a.equal('finish_selected_top',any(name in finish[0][0] for name in ('tb_axi_vga_completion.sv','tb_vga_buserr.sv')),True)
    if finish and stamps:a.equal('finish_time_after_call',finish[0].start()<stamps[0].start(),True)

    for line in text.splitlines():
        if re.search(r'VGA_TEST_UNIT_FAIL|\b(?:TIMEOUT|RESOURCE_INTERRUPTED)\b',line):a.lack('original_run_incomplete','The original run did not normally complete',text=line)


def review(kind,profile,run):
    a=Audit();verify_inputs(a);path=Path(run)/'stdout.log'
    if not path.is_file():a.lack('stdout','Original stdout is absent');return a.finish()
    before=path.stat();text=path.read_text(errors='replace');rows=rows_from_text(text,a);after=path.stat()

    if (before.st_size,before.st_mtime_ns)!=(after.st_size,after.st_mtime_ns):a.lack('stdout_stability','Original stdout changed while scanning')
    a.details['stdout']=dict(path=str(path),sha256=sha(path),bytes=after.st_size)
    meta=[r for r in rows if r['_kind']=='META'];finite_count(a,'meta_count',len(meta),1)
    if meta:a.equal('profile_binding',meta[0].get('profile'),profile);a.equal('kind_binding',meta[0].get('kind'),kind)
    begin=[integer(r.get('case')) for r in rows if r['_kind']=='CASE' and r.get('event')=='begin']
    end=[integer(r.get('case')) for r in rows if r['_kind']=='CASE' and r.get('event')=='end']
    sequence(a,'case_begin',begin,CASES[kind][profile]);sequence(a,'case_end',end,(CASES[kind][profile]))
    configurations=register_observations(rows,kind,a);pin_observations(rows,kind,profile,a);vga_errors=axi_observations(rows,kind,profile,a)
    lifecycle_observations(rows,kind,profile,configurations,a)
    configuration_lifecycle(rows,kind,configurations,a);fault_observations(rows,kind,profile,vga_errors,a)
    completion_observations(text,rows,kind,profile,a)
    a.details['version']='Public axi_vga completion checker'
    return a.finish()

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--kind',choices=['unit'],required=True);p.add_argument('--profile',required=True);p.add_argument('--run',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    args=p.parse_args()
    if args.profile not in CASES[args.kind]:p.error('Profile is not part of this finite kind')
    if args.output.exists():p.error('A new output file is required')
    result=review(args.kind,args.profile,args.run);args.output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(dict(passed=result['passed'],counts=result['details']['audit_counts'])));return 0 if result['passed'] else 1

if __name__=='__main__':raise SystemExit(main())
