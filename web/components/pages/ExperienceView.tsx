"use client";

import dynamic from "next/dynamic";
import ExperienceSimulatorPlaceholder from "../experience/ExperienceSimulatorPlaceholder";

const TuesdaySimulator = dynamic(() => import("../experience/TuesdaySimulator"), {
  loading: () => <ExperienceSimulatorPlaceholder />,
});

export default function ExperienceView() {
  return <TuesdaySimulator />;
}
