/** Reserved space while JourneyStage chunk loads — matches section shell dimensions. */
export default function JourneyStagePlaceholder() {
  return (
    <section
      id="experience"
      className="relative z-[1] section-x section-y-inset-top min-h-[80vh] md:min-h-[92vh]"
      aria-hidden
    />
  );
}
