import Hero from "@/components/home/Hero";
import CoachReasoning from "@/components/home/CoachReasoning";
import SeoIntro from "@/components/home/SeoIntro";
import JourneyStage from "@/components/home/JourneyStage";
import Pillars from "@/components/home/Pillars";
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
      <CoachReasoning />
      <SeoIntro />
      <JourneyStage />
      <Pillars />
      <Trust />
      <Download />
    </>
  );
}
