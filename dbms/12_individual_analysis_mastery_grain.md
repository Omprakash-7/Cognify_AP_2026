# CP5 Individual Analysis: Mastery Counts and Data Grain

## Question

What does the deck mastery query count when a learner has not reviewed every
card, and what schema assumption does the result depend on?

## Query shape

R5 starts with the deck's cards and left-joins `card_progress` for one learner.
That preserves cards without progress: the `NEW` count includes rows where the
progress state is null, while `total_deck_cards` counts all cards in the deck.
This is the intended behavior for an initial mastery view because an unseen
card should not disappear from the denominator.

## Grain assumption

The query expects at most one `card_progress` row per `(user_id, card_id)`.
The schema's composite primary key enforces that grain. If that uniqueness
constraint were removed, a card with duplicate progress records would multiply
the joined rows and inflate both the total and state counts.

## Interpretation

`average_ease_factor` uses `COALESCE(..., 2.50)`, so cards with no progress
contribute the default ease factor to the average. That choice treats unseen
cards as having a neutral initial factor; it is different from averaging only
reviewed cards. The report should preserve this distinction when describing the
metric.

## Evidence and validation

See R5 in `dbms/04_queries.sql` and the `card_progress` primary key in
`dbms/03_schema.sql`. A useful fixture includes one reviewed card in each
retention state plus at least one card with no progress, and checks total,
state counts, and the average separately.
