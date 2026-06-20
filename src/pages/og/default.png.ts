import type { APIContext } from "astro";
import { generateOgImage } from "../../lib/og";

export async function GET(_context: APIContext) {
  const png = await generateOgImage({
    title: "部落格",
    description: "書寫情感、認知心理學，與社會觀察。",
  });
  return new Response(png, {
    headers: { "Content-Type": "image/png" },
  });
}
