'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { createClient } from '../../lib/supabase-browser';
export default function LoginPage(){
 const [email,setEmail]=useState(''); const [password,setPassword]=useState(''); const [error,setError]=useState(''); const [busy,setBusy]=useState(false); const router=useRouter();
 async function submit(e:React.FormEvent){e.preventDefault();setBusy(true);setError('');try{const sb=createClient();const {error}=await sb.auth.signInWithPassword({email,password});if(error)throw error;router.replace('/dashboard');router.refresh();}catch(err){setError(err instanceof Error?err.message:'লগইন করা যায়নি।');}finally{setBusy(false)}}
 return <main className="wrap" style={{maxWidth:520}}><nav className="nav"><Link href="/" className="brand" style={{textDecoration:'none',color:'inherit'}}>TeamFlow</Link><Link href="/">হোম</Link></nav><section className="card"><h1>আপনার অ্যাকাউন্টে লগইন</h1><p className="muted">অ্যাডমিন বা আপনার দেওয়া ইমেইল ও পাসওয়ার্ড ব্যবহার করুন।</p><form onSubmit={submit}><label>ইমেইল<input className="field" type="email" autoComplete="username" required value={email} onChange={e=>setEmail(e.target.value)}/></label><label>পাসওয়ার্ড<input className="field" type="password" autoComplete="current-password" required minLength={8} value={password} onChange={e=>setPassword(e.target.value)}/></label><button className="btn" disabled={busy}>{busy?'লগইন হচ্ছে…':'লগইন করুন'}</button></form>{error&&<p className="danger" role="alert">{error}</p>}<p className="muted" style={{fontSize:13,marginTop:20}}>নতুন সদস্যের অ্যাকাউন্ট অ্যাডমিন তৈরি করবেন। পাবলিক সাইন-আপ বন্ধ রাখুন।</p></section></main>
}
