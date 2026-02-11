interface Props {
  score: number;
}

export function RatingStars({ score }: Props) {
  return (
    <span className="rating-cell">
      {"\u2605".repeat(score)}
    </span>
  );
}
