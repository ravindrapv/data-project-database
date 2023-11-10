-- Create the "matches" table
CREATE TABLE matches (
    id serial PRIMARY KEY,
    season integer,
    city text,
    date date,
    team1 text,
    team2 text,
    toss_winner text,
    toss_decision text,
    result text,
    dl_applied integer,
    winner text,
    win_by_runs integer,
    win_by_wickets integer,
    player_of_match text,
    venue text,
    umpire1 text,
    umpire2 text,
    umpire3 text
);

-- -- Create the "deliveries" table



CREATE TABLE deliveries (
    match_id integer,
    inning integer,
    batting_team text,
    bowling_team text,
    over integer,
    ball integer,
    batsman text,
    non_striker text,
    bowler text,
    is_super_over integer,
    wide_runs integer,
    bye_runs integer,
    legbye_runs integer,
    noball_runs integer,
    penalty_runs integer,
    batsman_runs integer,
    extra_runs integer,
    total_runs integer,
    player_dismissed text,
    dismissal_kind text,
    fielder text
);


--1.matchesPerYear 
SELECT
    season,
    COUNT(*) AS matchesPerYear
FROM
    matches
GROUP BY
    season
ORDER BY
    season;

-- 2.calculateMatchesWonPerTeamPerYear
SELECT
    season,
    winner AS team,
    COUNT(*) AS matchesWon
FROM
    matches
WHERE
    winner IS NOT NULL
GROUP BY
    season, winner
ORDER BY
    season, winner;

--3.calculateExtraRunsConcededIn2016
SELECT
    deliveries.bowling_team AS team,
    SUM(deliveries.extra_runs) AS extraRunsConceded
FROM
    deliveries
JOIN
    matches ON deliveries.match_id = matches.id
WHERE
    matches.season = 2016
GROUP BY
    deliveries.bowling_team
ORDER BY
    extraRunsConceded DESC;


--4 calculateTopEconomicalBowlersIn2015

WITH BowlerEconomy AS (
    SELECT
        d.bowler AS bowler,
        SUM(d.total_runs - d.extra_runs) AS runsConceded,
        COUNT(*) AS ballsBowled
    FROM
        deliveries AS d
    JOIN
        matches AS m ON d.match_id = m.id
    WHERE
        m.season = '2015'
    GROUP BY
        d.bowler
)
SELECT
    bowler,
    (SUM(runsConceded) / (SUM(ballsBowled) / 6)) AS economy
FROM
    BowlerEconomy
GROUP BY
    bowler
ORDER BY
    economy
LIMIT 10;


--.5 findTeamsTossAndMatchWins

SELECT
    toss_winner AS team,
    SUM(CASE WHEN toss_winner = winner THEN 1 ELSE 0 END) AS matchWins,
    COUNT(*) AS tossWins
FROM
    matches
WHERE
    toss_winner IS NOT NULL
    AND winner IS NOT NULL
GROUP BY
    toss_winner;

--6

WITH POTMAwards AS (
    SELECT
        season,
        player_of_match AS player,
        COUNT(*) AS awards
    FROM
        matches
    WHERE
        player_of_match IS NOT NULL
    GROUP BY
        season, player_of_match
),
RankedAwards AS (
    SELECT
        season,
        player,
        awards,
        RANK() OVER (PARTITION BY season ORDER BY awards DESC) AS ranking
    FROM
        POTMAwards
)
SELECT
    season,
    player,
    awards
FROM
    RankedAwards
WHERE
    ranking = 1
ORDER BY
    season;


--7.calculateBatsmanStrikeRate each year who has highest
WITH DhoniStats AS (
    SELECT
        m.season AS season,
        SUM(CASE WHEN d.batsman = 'MS Dhoni' THEN d.batsman_runs ELSE 0 END) AS dhoni_runs,
        SUM(CASE WHEN d.batsman = 'MS Dhoni' AND d.wide_runs = 0 THEN 1 ELSE 0 END) AS dhoni_balls
    FROM
        matches m
    LEFT JOIN
        deliveries d ON m.id = d.match_id
    GROUP BY
        m.season
)
SELECT
    season,
    ROUND(dhoni_runs * 100.0 / dhoni_balls, 2) AS strike_rate
FROM
    DhoniStats
WHERE
    dhoni_balls > 0
ORDER BY
    season;

--8 findDismissalStats
WITH DismissalStats AS (
    SELECT
        d.player_dismissed AS dismissedPlayer,
        d.bowler AS bowler,
        COUNT(*) AS dismissalCount
    FROM
        deliveries AS d
    WHERE
        d.player_dismissed IS NOT NULL
    GROUP BY
        d.player_dismissed,
        d.bowler
)
SELECT
    dismissedPlayer AS batsman,
    bowler,
    dismissalCount AS count
FROM
    DismissalStats
ORDER BY
    dismissalCount DESC
LIMIT 1;

-- 9.
WITH SuperOvers AS (
    SELECT
        d.bowler AS bowler,
        SUM(d.total_runs - d.bye_runs - d.legbye_runs) AS runsConceded,
        SUM(CASE WHEN d.noball_runs > 0 THEN 1 ELSE 0 END) AS noBallCount,
        SUM(CASE WHEN d.wide_runs > 0 THEN 1 ELSE 0 END) AS wideBallCount
    FROM
        deliveries AS d
    WHERE
        d.is_super_over = 1
    GROUP BY
        d.bowler
    HAVING
        COUNT(*) >= 6 
)
SELECT
    bowler,
    (SUM(runsConceded) - SUM(noBallCount) - SUM(wideBallCount)) / 1.0 AS economy
FROM
    SuperOvers
GROUP BY
    bowler
ORDER BY
    economy
LIMIT 1;

COPY matches FROM '/var/lib/postgresql/matches.csv' WITH CSV HEADER;
COPY deliveries FROM '/var/lib/postgresql/deliveries.csv' WITH CSV HEADER;

