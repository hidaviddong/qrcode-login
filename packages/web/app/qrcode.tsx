'use client';

import useSWR from 'swr';
import { useState } from 'react';
import { useRouter } from 'next/navigation';

interface QrCodeProps {
  svg: string;
  token: string;
}

const fetcher = (...args: Parameters<typeof fetch>) => fetch(...args).then((res) => res.json());

export default function Qrcode({ svg, token }: QrCodeProps) {
  const router = useRouter();
  const [shouldPoll, setShouldPoll] = useState(true);
  const pollKey = `http://localhost:3001/check-qrcode/${token}`;
  const { data, error, isLoading } = useSWR(shouldPoll ? pollKey : null, fetcher, {
    refreshInterval: 3000, 
    refreshWhenHidden: false,
    refreshWhenOffline: false,
    onSuccess: (data) => {
      if (data.status !== 'pending') {
        setShouldPoll(false);
        if (data.status === 'confirmed') {
          // TODO: 鉴权
          router.push('/test');
        }
      }
    },
    onError: (err) => {
      console.error('Error polling:', err);
      setShouldPoll(false);
    },
  });
  
  if(isLoading) {
    return <div>Loading...</div>
  }
  if(error) {
    return <div>Error: {error.message}</div>
  }

  return (
    <div>
      <div dangerouslySetInnerHTML={{ __html: svg }} className="w-48 h-48" />
      <p className={"text-md text-center " + (data?.status === 'confirmed' ? 'text-green-500' : 'text-red-500')}>{data?.status}</p>
    </div>
  );
}
