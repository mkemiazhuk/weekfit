import Hero from "@/components/home/Hero";
import SeoIntro from "@/components/home/SeoIntro";
import WhyWeekFit from "@/components/home/WhyWeekFit";
import JourneyStage from "@/components/home/JourneyStage";
import Pillars from "@/components/home/Pillars";
import Trust from "@/components/home/Trust";
import Download from "@/components/home/Download";

export default function Home() {
  return (
    <>
      <Hero />
      <SeoIntro />
      <WhyWeekFit />
      <JourneyStage />
      <Pillars />
      <Trust />
      <Download />
    </>
  );
}
