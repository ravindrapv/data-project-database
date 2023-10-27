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
    deliveries.batting_team AS team,
    SUM(deliveries.extra_runs) AS extraRunsConceded
FROM
    deliveries
JOIN
    matches ON deliveries.match_id = matches.id
WHERE
    matches.season = 2016
GROUP BY
    deliveries.batting_team
ORDER BY
    extraRunsConceded DESC;


--4 calculateTopEconomicalBowlersIn2015

WITH RunsConcededPerBowler AS (
    SELECT
        d.bowler AS bowler,
        SUM(d.total_runs - d.bye_runs - d.legbye_runs) AS runsConceded,
        SUM(CASE WHEN d.noball_runs > 0 THEN 1 ELSE 0 END) AS noBallCount,
        SUM(CASE WHEN d.wide_runs > 0 THEN 1 ELSE 0 END) AS wideBallCount
    FROM
        deliveries AS d
    JOIN
        matches AS m ON d.match_id = m.id
    WHERE
        m.season = 2015
    GROUP BY
        d.bowler
    HAVING
        COUNT(*) >= 100 -- Assuming bowlers with 100 or more balls
)
SELECT
    rcb.bowler AS bowler,
    (SUM(rcb.runsConceded) - SUM(rcb.noBallCount) - SUM(rcb.wideBallCount)) AS runsExcludingExtras,
    (SUM(rcb.runsConceded) - SUM(rcb.noBallCount) - SUM(rcb.wideBallCount)) / (SUM(rcb.noBallCount) + SUM(rcb.wideBallCount)) AS economy
FROM
    RunsConcededPerBowler AS rcb
GROUP BY
    rcb.bowler
HAVING
    SUM(rcb.noBallCount) + SUM(rcb.wideBallCount) > 0
ORDER BY
    economy
LIMIT 10;WITH RunsConcededPerBowler AS (
    SELECT
        d.bowler AS bowler,
        SUM(d.total_runs - d.bye_runs - d.legbye_runs) AS runsConceded,
        SUM(CASE WHEN d.noball_runs > 0 THEN 1 ELSE 0 END) AS noBallCount,
        SUM(CASE WHEN d.wide_runs > 0 THEN 1 ELSE 0 END) AS wideBallCount
    FROM
        deliveries AS d
    JOIN
        matches AS m ON d.match_id = m.id
    WHERE
        m.season = 2015
    GROUP BY
        d.bowler
    HAVING
        COUNT(*) >= 100 -- Assuming bowlers with 100 or more balls
)
SELECT
    rcb.bowler AS bowler,
    (SUM(rcb.runsConceded) - SUM(rcb.noBallCount) - SUM(rcb.wideBallCount)) AS runsExcludingExtras,
    (SUM(rcb.runsConceded) - SUM(rcb.noBallCount) - SUM(rcb.wideBallCount)) / (SUM(rcb.noBallCount) + SUM(rcb.wideBallCount)) AS economy
FROM
    RunsConcededPerBowler AS rcb
GROUP BY
    rcb.bowler
HAVING
    SUM(rcb.noBallCount) + SUM(rcb.wideBallCount) > 0
ORDER BY
    economy
LIMIT 10;


--.5 findTeamsTossAndMatchWins

WITH TossWins AS (
    SELECT
        team1 AS team,
        COUNT(*) AS toss_wins
    FROM
        matches
    WHERE
        toss_winner = team1
    GROUP BY
        team1
    UNION ALL
    SELECT
        team2 AS team,
        COUNT(*) AS toss_wins
    FROM
        matches
    WHERE
        toss_winner = team2
    GROUP BY
        team2
),
MatchWins AS (
    SELECT
        winner AS team,
        COUNT(*) AS match_wins
    FROM
        matches
    WHERE
        winner IS NOT NULL
    GROUP BY
        winner
)
SELECT
    COALESCE(T.team, M.team) AS team,
    COALESCE(T.toss_wins, 0) AS toss_wins,
    COALESCE(M.match_wins, 0) AS match_wins
FROM
    TossWins AS T
FULL JOIN
    MatchWins AS M
ON
    T.team = M.team
ORDER BY
    team;



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
WITH BatsmanStats AS (
    SELECT
        m.season,
        d.batsman AS batsman,
        SUM(d.batsman_runs) AS total_runs,
        COUNT(*) AS balls_faced
    FROM
        deliveries AS d
    JOIN
        matches AS m ON d.match_id = m.id
    WHERE
        m.season IS NOT NULL
    GROUP BY
        m.season, d.batsman
),
StrikeRate AS (
    SELECT
        season,
        batsman,
        total_runs,
        balls_faced,
        (total_runs * 100.0) / balls_faced AS strike_rate
    FROM
        BatsmanStats
),
MaxStrikeRatePerYear AS (
    SELECT
        season,
        MAX(strike_rate) AS max_strike_rate
    FROM
        StrikeRate
    GROUP BY
        season
)
SELECT
    msr.season,
    sr.batsman AS batsman_with_highest_strike_rate,
    msr.max_strike_rate
FROM
    MaxStrikeRatePerYear AS msr
JOIN
    StrikeRate AS sr ON msr.season = sr.season AND msr.max_strike_rate = sr.strike_rate;


--8 findDismissalStats
WITH DismissalStats AS (
    SELECT
        d.batsman AS batsman,
        d.player_dismissed AS dismissed_player,
        COUNT(*) AS dismissals
    FROM
        deliveries AS d
    WHERE
        d.player_dismissed IS NOT NULL
    GROUP BY
        d.batsman, d.player_dismissed
),
TopDismissals AS (
    SELECT
        ds.batsman AS batsman_with_highest_dismissals,
        ds.dismissed_player AS bowler_with_most_dismissals,
        MAX(ds.dismissals) AS max_dismissals
    FROM
        DismissalStats AS ds
    GROUP BY
        ds.batsman, ds.dismissed_player
    ORDER BY
        MAX(ds.dismissals) DESC
    LIMIT 1
)
SELECT
    top.batsman_with_highest_dismissals,
    top.bowler_with_most_dismissals,
    top.max_dismissals
FROM
    TopDismissals AS top;

-- 9.
WITH SuperOvers AS (
    SELECT
        d.match_id,
        d.over,
        m.team2 AS team_bowling,
        d.bowler,
        SUM(d.total_runs) AS runs_given
    FROM
        deliveries AS d
    JOIN
        matches AS m ON d.match_id = m.id
    WHERE
        d.is_super_over = 1
    GROUP BY
        d.match_id, d.over, m.team2, d.bowler
),
SuperOverEconomy AS (
    SELECT
        team_bowling,
        bowler,
        SUM(runs_given) AS total_runs_given,
        COUNT(DISTINCT over) AS overs_bowled
    FROM
        SuperOvers
    GROUP BY
        team_bowling, bowler
),
BestSuperOverEconomy AS (
    SELECT
        team_bowling,
        bowler,
        (total_runs_given * 6.0) / overs_bowled AS economy_rate
    FROM
        SuperOverEconomy
)
SELECT
    team_bowling,
    bowler,
    economy_rate
FROM
    BestSuperOverEconomy
ORDER BY
    economy_rate
LIMIT 1;


COPY matches FROM '/var/lib/postgresql/matches.csv' WITH CSV HEADER;
COPY deliveries FROM '/var/lib/postgresql/deliveries.csv' WITH CSV HEADER;

