import { renderSVG } from "uqr";
import Qrcode from "./qrcode";

export default async function Home() {
  const res = await fetch('http://localhost:3001/generate-qrcode')
  const { token } = await res.json()
  const svg = renderSVG(token)

  return (
    <div className="w-full h-screen flex items-center justify-center bg-slate-100">
       <Qrcode svg={svg} token={token} />
    </div>
  );
}
