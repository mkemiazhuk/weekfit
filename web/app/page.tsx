import Hero from "@/components/home/Hero";
import ProofStrip from "@/components/home/ProofStrip";
import SeoIntro from "@/components/home/SeoIntro";
import CoachReasoning from "@/components/home/CoachReasoning";
import JourneyStage from "@/components/home/JourneyStage";
import Trust from "@/components/home/Trust";
import Download from "@/components/home/Download";
import JsonLd from "@/components/JsonLd";
import { entityGraphSchema } from "@/lib/schema";
import { homeMetadata } from "@/lib/page-factory";

export const metadata = homeMetadata("en");

export default function Home() {
  return (
    <>
      <JsonLd data={entityGraphSchema()} />
      <Hero />
      <ProofStrip />
      <SeoIntro />
      <CoachReasoning />
      <JourneyStage />
      <Trust />
      <Download />
    </>
  );
}
