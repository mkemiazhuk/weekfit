import dynamic from "next/dynamic";
import Hero from "@/components/home/Hero";
import ProofStrip from "@/components/home/ProofStrip";
import SeoIntro from "@/components/home/SeoIntro";
import UseCases from "@/components/home/UseCases";
import CoachReasoning from "@/components/home/CoachReasoning";
import Trust from "@/components/home/Trust";
import Download from "@/components/home/Download";
import JourneyStagePlaceholder from "@/components/home/JourneyStagePlaceholder";
import { homeMetadata } from "@/lib/page-factory";

const JourneyStage = dynamic(() => import("@/components/home/JourneyStage"), {
  loading: () => <JourneyStagePlaceholder />,
});

export const metadata = homeMetadata("en");

export default function Home() {
  return (
    <>
      <Hero />
      <ProofStrip />
      <SeoIntro />
      <UseCases />
      <CoachReasoning />
      <JourneyStage />
      <Trust />
      <Download />
    </>
  );
}
