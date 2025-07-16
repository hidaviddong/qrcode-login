'use client'

import useSWR from "swr"


const fetcher = async (...args: Parameters<typeof fetch>) => {
    const res = await fetch(...args);
    if (!res.ok) {
      const errorText = await res.text(); 
      const error = new Error(`Failed to fetch: ${res.status} ${res.statusText} - ${errorText}`);
      (error as any).status = res.status;
      throw error;
    }
    return res.json();
  };



export default function Protected() {
    const protectedKey = `http://localhost:3001/protected`
    const { data: protectedData, error: protectedError, isLoading: protectedLoading } = useSWR(protectedKey, fetcher, {
        refreshInterval: 3000, 
        refreshWhenHidden: false,
        refreshWhenOffline: false,
        shouldRetryOnError: false,
    });
    if(protectedLoading) {
        return <div>Loading...</div>
    }
    if(protectedError) {
        return <div>{protectedError.message}</div>
    }
    return <div>{protectedData.message}</div>
}