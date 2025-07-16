'use client';

import useSWR, { mutate } from 'swr';
import { useState } from 'react';

interface QrCodeProps {
  svg: string;
  token: string;
}


const fetcher = (...args: Parameters<typeof fetch>) => fetch(...args).then((res) => res.json());

export default function Qrcode({ svg, token }: QrCodeProps) {
  const [shouldPoll, setShouldPoll] = useState(true);
  const pollKey = `http://localhost:3001/check-qrcode/${token}`;
  const { data, error, isLoading } = useSWR(shouldPoll ? pollKey : null, fetcher, {
    refreshInterval: 3000, 
    refreshWhenHidden: false,
    refreshWhenOffline: false,
    onSuccess: (data) => {
      if (data.status === 'confirmed') {
        sessionStorage.setItem('qrcode-auth-token', data.authToken)
        mutate('http://localhost:3001/protected')
        setShouldPoll(false);
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
        !sessionStorage.getItem('qrcode-auth-token') ? (
            <div>
                <div dangerouslySetInnerHTML={{ __html: svg }} className="w-48 h-48" />
                <p className={"text-md text-center " + (data?.status === 'confirmed' ? 'text-green-500' : 'text-red-500')}>{data?.status}</p>
            </div>
        ) : (
            <></>
        )
    
  )
}
