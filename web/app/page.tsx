import dynamic from "next/dynamic";
import Hero from "@/components/home/Hero";
import ProofStrip from "@/components/home/ProofStrip";
import JourneyStagePlaceholder from "@/components/home/JourneyStagePlaceholder";
import { homeMetadata } from "@/lib/page-factory";

const SeoIntro = dynamic(() => import("@/components/home/SeoIntro"));
const UseCases = dynamic(() => import("@/components/home/UseCases"));
const CoachReasoning = dynamic(() => import("@/components/home/CoachReasoning"));
const Trust = dynamic(() => import("@/components/home/Trust"));
const Download = dynamic(() => import("@/components/home/Download"));
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
