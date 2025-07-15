import { renderSVG } from "uqr";

export default function Home() {
  
  const svg = renderSVG('Hello, World!')
  return (
    <div className="w-full h-screen flex items-center justify-center bg-slate-100">
       <div dangerouslySetInnerHTML={{__html:svg}} className="w-48 h-48" />
    </div>
  );
}
