import type { Metadata } from 'next';
import './globals.css';
export const metadata: Metadata = { title: 'TeamFlow | Team & Payments', description: 'Team projects, work tracking and payments' };
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) { return <html lang="bn"><body>{children}</body></html>; }
