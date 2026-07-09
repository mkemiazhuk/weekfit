import Hero from "@/components/home/Hero";
import ProofStrip from "@/components/home/ProofStrip";
import CoachReasoning from "@/components/home/CoachReasoning";
import JourneyStage from "@/components/home/JourneyStage";
import Trust from "@/components/home/Trust";
import Download from "@/components/home/Download";
import JsonLd from "@/components/JsonLd";
import { entityGraphSchema } from "@/lib/schema";
import { homeMetadata } from "@/lib/page-factory";

export const metadata = homeMetadata("ru");

export default function RuHomePage() {
  return (
    <>
      <JsonLd data={entityGraphSchema()} />
      <Hero />
      <ProofStrip />
      <CoachReasoning />
      <JourneyStage />
      <Trust />
      <Download />
    </>
  );
}
