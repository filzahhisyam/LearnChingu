CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$ BEGIN
  CREATE TYPE form_level AS ENUM ('FORM_4', 'FORM_5');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE difficulty AS ENUM ('EASY', 'MEDIUM', 'HARD');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE question_type AS ENUM ('OBJECTIVE', 'STRUCTURED');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE mastery_level AS ENUM ('weak', 'developing', 'strong');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS student_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  form_level form_level NOT NULL,
  confidence_rating INT CHECK (confidence_rating BETWEEN 1 AND 5),
  diagnostic_completed BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS topics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  code TEXT UNIQUE NOT NULL,
  form_level form_level NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  topic_id UUID REFERENCES topics(id),
  form_level form_level NOT NULL,
  difficulty difficulty NOT NULL,
  type question_type NOT NULL,
  content TEXT NOT NULL,
  options JSONB,
  correct_answer TEXT NOT NULL,
  explanation TEXT NOT NULL,
  is_diagnostic BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS topic_performances (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  topic_id UUID REFERENCES topics(id),
  correct_count INT DEFAULT 0,
  attempt_count INT DEFAULT 0,
  mastery_score FLOAT DEFAULT 0.0 CHECK (mastery_score BETWEEN 0.0 AND 1.0),
  last_attempt_at TIMESTAMPTZ,
  UNIQUE(user_id, topic_id)
);

CREATE TABLE IF NOT EXISTS quiz_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  topic_id UUID REFERENCES topics(id),
  started_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  score FLOAT
);

CREATE TABLE IF NOT EXISTS quiz_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID REFERENCES quiz_sessions(id) ON DELETE CASCADE,
  question_id UUID REFERENCES questions(id),
  user_answer TEXT NOT NULL,
  is_correct BOOLEAN NOT NULL,
  time_spent_seconds INT NOT NULL,
  answered_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS working_evaluations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  question_id UUID REFERENCES questions(id),
  question_content TEXT NOT NULL,
  image_base64 TEXT NOT NULL,
  ai_feedback JSONB NOT NULL,
  is_correct BOOLEAN,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS tutoring_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  messages JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_student_profiles_updated_at ON student_profiles;
CREATE TRIGGER set_student_profiles_updated_at
BEFORE UPDATE ON student_profiles
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS set_tutoring_sessions_updated_at ON tutoring_sessions;
CREATE TRIGGER set_tutoring_sessions_updated_at
BEFORE UPDATE ON tutoring_sessions
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE student_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE topic_performances ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE working_evaluations ENABLE ROW LEVEL SECURITY;
ALTER TABLE tutoring_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own profile" ON student_profiles;
CREATE POLICY "Users manage own profile" ON student_profiles FOR ALL USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users manage own performance" ON topic_performances;
CREATE POLICY "Users manage own performance" ON topic_performances FOR ALL USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users manage own sessions" ON quiz_sessions;
CREATE POLICY "Users manage own sessions" ON quiz_sessions FOR ALL USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users manage own attempts" ON quiz_attempts;
CREATE POLICY "Users manage own attempts" ON quiz_attempts FOR ALL USING (
  session_id IN (SELECT id FROM quiz_sessions WHERE user_id = auth.uid())
);

DROP POLICY IF EXISTS "Users manage own evaluations" ON working_evaluations;
CREATE POLICY "Users manage own evaluations" ON working_evaluations FOR ALL USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users manage own tutoring" ON tutoring_sessions;
CREATE POLICY "Users manage own tutoring" ON tutoring_sessions FOR ALL USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Topics are public" ON topics;
CREATE POLICY "Topics are public" ON topics FOR SELECT USING (true);

DROP POLICY IF EXISTS "Questions are public" ON questions;
CREATE POLICY "Questions are public" ON questions FOR SELECT USING (true);

INSERT INTO topics (name, code, form_level) VALUES
('Quadratic Functions', 'quadratic-functions', 'FORM_4'),
('Algebra', 'algebra', 'FORM_4'),
('Statistics', 'statistics', 'FORM_4'),
('Geometry', 'geometry', 'FORM_4'),
('Trigonometry', 'trigonometry', 'FORM_4'),
('Probability', 'probability', 'FORM_4'),
('Functions', 'functions', 'FORM_5'),
('Matrices', 'matrices', 'FORM_5'),
('Vectors', 'vectors', 'FORM_5'),
('Linear Programming', 'linear-programming', 'FORM_5')
ON CONFLICT (code) DO NOTHING;

INSERT INTO questions (topic_id, form_level, difficulty, type, content, options, correct_answer, explanation, is_diagnostic) VALUES
((SELECT id FROM topics WHERE code = 'quadratic-functions'), 'FORM_4', 'EASY', 'OBJECTIVE', 'Which of these is a quadratic equation?', '["x + 3 = 0", "x^2 + 3x - 4 = 0", "x^3 - 2 = 0", "2/x = 5"]', 'B', 'A quadratic equation has the form ax^2 + bx + c = 0 where a ≠ 0. Only option B fits.', TRUE),
((SELECT id FROM topics WHERE code = 'quadratic-functions'), 'FORM_4', 'MEDIUM', 'OBJECTIVE', 'Factorise x^2 - 7x + 12.', '["(x-1)(x-12)", "(x-3)(x-4)", "(x+3)(x+4)", "(x-6)^2"]', 'B', 'The factors of 12 that add to -7 are -3 and -4, so the factorisation is (x-3)(x-4).', TRUE),
((SELECT id FROM topics WHERE code = 'quadratic-functions'), 'FORM_4', 'EASY', 'OBJECTIVE', 'Find the value of x if x^2 = 25 and x is positive.', '["-5", "0", "5", "25"]', 'C', 'Since x is positive, x = 5.', FALSE),
((SELECT id FROM topics WHERE code = 'quadratic-functions'), 'FORM_4', 'MEDIUM', 'OBJECTIVE', 'If the roots of x^2 - 5x + 6 = 0 are p and q, what is p+q?', '["6", "5", "-5", "-6"]', 'B', 'For x^2 - 5x + 6 = 0, sum of roots = 5.', FALSE),
((SELECT id FROM topics WHERE code = 'quadratic-functions'), 'FORM_4', 'HARD', 'STRUCTURED', 'Solve x^2 - 5x + 6 = 0 by factorisation.', NULL, 'x^2 - 5x + 6 = 0 -> (x-2)(x-3) = 0 -> x = 2 or x = 3. Expand to check: 2^2 - 10 + 6 = 0 and 3^2 - 15 + 6 = 0.', FALSE),
((SELECT id FROM topics WHERE code = 'quadratic-functions'), 'FORM_4', 'HARD', 'STRUCTURED', 'A ball is thrown and its height is modelled by h = -t^2 + 4t + 5. Find the maximum height.', NULL, 'The vertex occurs at t = -b/(2a) = -4/(2(-1)) = 2. Substituting gives h = -(2^2) + 4(2) + 5 = 9. The maximum height is 9.', FALSE),

((SELECT id FROM topics WHERE code = 'algebra'), 'FORM_4', 'EASY', 'OBJECTIVE', 'Solve 2x + 3 = 11.', '["x=3", "x=4", "x=5", "x=7"]', 'B', '2x = 8, so x = 4.', TRUE),
((SELECT id FROM topics WHERE code = 'algebra'), 'FORM_4', 'MEDIUM', 'OBJECTIVE', 'Simplify 3a - 2a + 5.', '["a+5", "a-5", "5a", "2a+5"]', 'A', '3a - 2a = a, so the expression becomes a + 5.', TRUE),
((SELECT id FROM topics WHERE code = 'algebra'), 'FORM_4', 'EASY', 'OBJECTIVE', 'What is 7m when m = 2?', '["9", "12", "14", "16"]', 'C', '7 × 2 = 14.', FALSE),
((SELECT id FROM topics WHERE code = 'algebra'), 'FORM_4', 'MEDIUM', 'OBJECTIVE', 'Expand 2(x + 4).', '["2x+4", "2x+8", "x+8", "2x-8"]', 'B', 'Multiply both terms by 2 to get 2x + 8.', FALSE),
((SELECT id FROM topics WHERE code = 'algebra'), 'FORM_4', 'HARD', 'STRUCTURED', 'Solve 3(x - 1) = 2(x + 4).', NULL, '3x - 3 = 2x + 8, so x = 11. Check: 3(10) = 30 and 2(15) = 30.', FALSE),
((SELECT id FROM topics WHERE code = 'algebra'), 'FORM_4', 'HARD', 'STRUCTURED', 'Rearrange y = 5x - 2 to make x the subject.', NULL, 'Add 2 to both sides: y + 2 = 5x. Then divide by 5: x = (y + 2)/5.', FALSE),

((SELECT id FROM topics WHERE code = 'statistics'), 'FORM_4', 'EASY', 'OBJECTIVE', 'Find the mean of 2, 4, 6.', '["2", "4", "6", "12"]', 'B', 'Mean = (2+4+6)/3 = 4.', TRUE),
((SELECT id FROM topics WHERE code = 'statistics'), 'FORM_4', 'MEDIUM', 'OBJECTIVE', 'What is the median of 3, 8, 5, 2, 10?', '["3", "5", "8", "10"]', 'B', 'Order the values: 2,3,5,8,10. The middle value is 5.', TRUE),
((SELECT id FROM topics WHERE code = 'statistics'), 'FORM_4', 'EASY', 'OBJECTIVE', 'The mode of 1, 2, 2, 3, 4 is...', '["1", "2", "3", "4"]', 'B', '2 appears most often.', FALSE),
((SELECT id FROM topics WHERE code = 'statistics'), 'FORM_4', 'MEDIUM', 'OBJECTIVE', 'A pie chart has 25% shaded. What fraction is this?', '["1/2", "1/4", "1/5", "3/4"]', 'B', '25% = 25/100 = 1/4.', FALSE),
((SELECT id FROM topics WHERE code = 'statistics'), 'FORM_4', 'HARD', 'STRUCTURED', 'The marks 4, 6, 7, 9, 4, 8, 2, 10 are obtained by 8 students. Find the mean and median.', NULL, 'Mean = 50/8 = 6.25. Order the data: 2,4,4,6,7,8,9,10. Median = (6+7)/2 = 6.5.', FALSE),
((SELECT id FROM topics WHERE code = 'statistics'), 'FORM_4', 'HARD', 'STRUCTURED', 'A grouped frequency table has class 0-10, 10-20, 20-30 with frequencies 3, 5, 2. Find the estimated mean.', NULL, 'Use midpoints 5, 15, 25. Estimated mean = (3(5)+5(15)+2(25))/(3+5+2) = (15+75+50)/10 = 14.', FALSE),

((SELECT id FROM topics WHERE code = 'geometry'), 'FORM_4', 'EASY', 'OBJECTIVE', 'The sum of angles in a triangle is...', '["90°", "180°", "270°", "360°"]', 'B', 'A triangle has interior angles totaling 180°.', TRUE),
((SELECT id FROM topics WHERE code = 'geometry'), 'FORM_4', 'MEDIUM', 'OBJECTIVE', 'A right angle is equal to...', '["45°", "60°", "90°", "120°"]', 'C', 'A right angle is 90°.', TRUE),
((SELECT id FROM topics WHERE code = 'geometry'), 'FORM_4', 'EASY', 'OBJECTIVE', 'A square has how many equal sides?', '["2", "3", "4", "5"]', 'C', 'A square has four equal sides.', FALSE),
((SELECT id FROM topics WHERE code = 'geometry'), 'FORM_4', 'MEDIUM', 'OBJECTIVE', 'The area of a rectangle is found by...', '["l+w", "2(l+w)", "l×w", "l-w"]', 'C', 'Area of a rectangle = length × width.', FALSE),
((SELECT id FROM topics WHERE code = 'geometry'), 'FORM_4', 'HARD', 'STRUCTURED', 'In a triangle, the angles are 2x, 3x and 5x. Find x and each angle.', NULL, '2x+3x+5x=180, so 10x=180 and x=18. The angles are 36°, 54° and 90°.', FALSE),
((SELECT id FROM topics WHERE code = 'geometry'), 'FORM_4', 'HARD', 'STRUCTURED', 'A circle has radius 7 cm. Find its circumference in terms of π.', NULL, 'Circumference = 2πr = 2π(7) = 14π cm.', FALSE),

((SELECT id FROM topics WHERE code = 'trigonometry'), 'FORM_4', 'EASY', 'OBJECTIVE', 'sin 30° is equal to...', '["1/2", "1", "\u221a2/2", "\u221a3/2"]', 'A', 'sin 30° = 1/2.', TRUE),
((SELECT id FROM topics WHERE code = 'trigonometry'), 'FORM_4', 'MEDIUM', 'OBJECTIVE', 'cos 0° is equal to...', '["0", "1", "1/2", "\u221a3/2"]', 'B', 'cos 0° = 1.', TRUE),
((SELECT id FROM topics WHERE code = 'trigonometry'), 'FORM_4', 'EASY', 'OBJECTIVE', 'In a right triangle, tan θ = ...', '["opposite/adjacent", "adjacent/hypotenuse", "opposite/hypotenuse", "hypotenuse/opposite"]', 'A', 'tan = opposite ÷ adjacent.', FALSE),
((SELECT id FROM topics WHERE code = 'trigonometry'), 'FORM_4', 'MEDIUM', 'OBJECTIVE', 'If opposite = 3 and adjacent = 4, tan θ =', '["3/4", "4/3", "5/4", "3/5"]', 'A', 'tan θ = opposite/adjacent = 3/4.', FALSE),
((SELECT id FROM topics WHERE code = 'trigonometry'), 'FORM_4', 'HARD', 'STRUCTURED', 'A ladder 10 m long makes an angle of 60° with the ground. Find the height reached by the ladder.', NULL, 'Use sin 60° = height/10. Height = 10(\u221a3/2) = 5\u221a3 m \u2248 8.66 m.', FALSE),
((SELECT id FROM topics WHERE code = 'trigonometry'), 'FORM_4', 'HARD', 'STRUCTURED', 'A right triangle has hypotenuse 13 cm and one side 5 cm. Find the other side.', NULL, 'By Pythagoras, other side = \u221a(13^2 - 5^2) = \u221a144 = 12 cm.', FALSE),

((SELECT id FROM topics WHERE code = 'probability'), 'FORM_4', 'EASY', 'OBJECTIVE', 'The probability of getting heads on a fair coin is...', '["0", "1/4", "1/2", "1"]', 'C', 'A fair coin has two equally likely outcomes.', TRUE),
((SELECT id FROM topics WHERE code = 'probability'), 'FORM_4', 'MEDIUM', 'OBJECTIVE', 'A bag has 3 red and 2 blue balls. Probability of drawing red is...', '["2/5", "3/5", "1/2", "3/2"]', 'B', 'Red = 3 out of 5 balls.', TRUE),
((SELECT id FROM topics WHERE code = 'probability'), 'FORM_4', 'EASY', 'OBJECTIVE', 'The probability of an impossible event is...', '["0", "1/2", "1", "2"]', 'A', 'Impossible events have probability 0.', FALSE),
((SELECT id FROM topics WHERE code = 'probability'), 'FORM_4', 'MEDIUM', 'OBJECTIVE', 'If P(A) = 0.7, then P(not A) =', '["0.1", "0.2", "0.3", "0.7"]', 'C', 'Complementary probability = 1 - 0.7 = 0.3.', FALSE),
((SELECT id FROM topics WHERE code = 'probability'), 'FORM_4', 'HARD', 'STRUCTURED', 'A box contains 4 green, 3 yellow and 5 black marbles. Find the probability of not drawing yellow.', NULL, 'Total = 12. Not yellow = 4+5 = 9. Probability = 9/12 = 3/4.', FALSE),
((SELECT id FROM topics WHERE code = 'probability'), 'FORM_4', 'HARD', 'STRUCTURED', 'Two fair dice are thrown. Find the probability that the sum is 7.', NULL, 'There are 6 outcomes with sum 7: (1,6),(2,5),(3,4),(4,3),(5,2),(6,1). Probability = 6/36 = 1/6.', FALSE),

((SELECT id FROM topics WHERE code = 'functions'), 'FORM_5', 'EASY', 'OBJECTIVE', 'If f(x) = 2x + 1, find f(3).', '["5", "6", "7", "8"]', 'C', 'f(3) = 2(3)+1 = 7.', TRUE),
((SELECT id FROM topics WHERE code = 'functions'), 'FORM_5', 'MEDIUM', 'OBJECTIVE', 'If g(x) = x^2, then g(4) =', '["8", "12", "16", "20"]', 'C', '4^2 = 16.', TRUE),
((SELECT id FROM topics WHERE code = 'functions'), 'FORM_5', 'EASY', 'OBJECTIVE', 'The range of a function is...', '["all possible input values", "all possible output values", "the gradient", "the x-intercept"]', 'B', 'Range means the set of output values.', FALSE),
((SELECT id FROM topics WHERE code = 'functions'), 'FORM_5', 'MEDIUM', 'OBJECTIVE', 'If f(x)=x-2, then f(0)=', '["-2", "0", "2", "4"]', 'A', 'Substitute x=0 to get -2.', FALSE),
((SELECT id FROM topics WHERE code = 'functions'), 'FORM_5', 'HARD', 'STRUCTURED', 'Given f(x)=3x-5, find f(2) and solve f(x)=4.', NULL, 'f(2)=1. For f(x)=4, 3x-5=4 so 3x=9 and x=3.', FALSE),
((SELECT id FROM topics WHERE code = 'functions'), 'FORM_5', 'HARD', 'STRUCTURED', 'If f(x)=2x+3 and g(x)=x^2, find gf(2).', NULL, 'First f(2)=7. Then g(f(2))=g(7)=49.', FALSE),

((SELECT id FROM topics WHERE code = 'matrices'), 'FORM_5', 'EASY', 'OBJECTIVE', 'What is the order of a 2x3 matrix?', '["2 rows and 3 columns", "3 rows and 2 columns", "2 rows and 2 columns", "3 rows and 3 columns"]', 'A', '2x3 means 2 rows and 3 columns.', TRUE),
((SELECT id FROM topics WHERE code = 'matrices'), 'FORM_5', 'MEDIUM', 'OBJECTIVE', 'Find [[1,2],[3,4]] + [[2,1],[0,5]].', '["[[3,3],[3,9]]", "[[1,1],[3,9]]", "[[2,3],[3,4]]", "[[3,2],[4,9]]"]', 'A', 'Add corresponding entries.', TRUE),
((SELECT id FROM topics WHERE code = 'matrices'), 'FORM_5', 'EASY', 'OBJECTIVE', 'A matrix element in row 1 column 2 is written as...', '["a12", "a21", "a11", "a22"]', 'A', 'Row index comes first, then column index.', FALSE),
((SELECT id FROM topics WHERE code = 'matrices'), 'FORM_5', 'MEDIUM', 'OBJECTIVE', 'If A = [[1,0],[0,1]], A is the...', '["zero matrix", "identity matrix", "row matrix", "column matrix"]', 'B', 'This is the identity matrix.', FALSE),
((SELECT id FROM topics WHERE code = 'matrices'), 'FORM_5', 'HARD', 'STRUCTURED', 'Multiply [[1,2],[0,3]] by [[2],[4]].', NULL, 'Result = [[1(2)+2(4)], [0(2)+3(4)]] = [[10],[12]].', FALSE),
((SELECT id FROM topics WHERE code = 'matrices'), 'FORM_5', 'HARD', 'STRUCTURED', 'Find the determinant of [[3,1],[2,5]].', NULL, 'det = 3(5) - 1(2) = 13.', FALSE),

((SELECT id FROM topics WHERE code = 'vectors'), 'FORM_5', 'EASY', 'OBJECTIVE', 'A vector has magnitude and...', '["speed", "direction", "area", "mass"]', 'B', 'A vector has magnitude and direction.', TRUE),
((SELECT id FROM topics WHERE code = 'vectors'), 'FORM_5', 'MEDIUM', 'OBJECTIVE', 'If vector a = (2,3) and b = (1,4), then a+b =', '["(3,7)", "(2,12)", "(1,1)", "(3,1)"]', 'A', 'Add corresponding components.', TRUE),
((SELECT id FROM topics WHERE code = 'vectors'), 'FORM_5', 'EASY', 'OBJECTIVE', 'The vector from (1,1) to (4,1) is...', '["(1,4)", "(3,0)", "(4,3)", "(0,3)"]', 'B', 'Change in x is 3 and change in y is 0.', FALSE),
((SELECT id FROM topics WHERE code = 'vectors'), 'FORM_5', 'MEDIUM', 'OBJECTIVE', 'The midpoint of (2,4) and (6,4) is...', '["(3,4)", "(4,4)", "(5,4)", "(6,4)"]', 'B', 'Average each coordinate: ((2+6)/2, (4+4)/2) = (4,4).', FALSE),
((SELECT id FROM topics WHERE code = 'vectors'), 'FORM_5', 'HARD', 'STRUCTURED', 'Given vectors u=(3,1) and v=(1,4), find 2u-v.', NULL, '2u=(6,2). Subtract v to get (6-1,2-4)=(5,-2).', FALSE),
((SELECT id FROM topics WHERE code = 'vectors'), 'FORM_5', 'HARD', 'STRUCTURED', 'A point P moves 5 units right and 2 units up. Write the displacement vector.', NULL, 'The displacement vector is (5,2).', FALSE),

((SELECT id FROM topics WHERE code = 'linear-programming'), 'FORM_5', 'EASY', 'OBJECTIVE', 'Linear programming involves...', '["equations only", "optimising an objective", "finding derivatives", "drawing circles"]', 'B', 'It is about maximising or minimising under constraints.', TRUE),
((SELECT id FROM topics WHERE code = 'linear-programming'), 'FORM_5', 'MEDIUM', 'OBJECTIVE', 'A constraint x + y <= 10 is represented by...', '["a region", "a straight line only", "a curve", "a point only"]', 'A', 'An inequality represents a region on the graph.', TRUE),
((SELECT id FROM topics WHERE code = 'linear-programming'), 'FORM_5', 'EASY', 'OBJECTIVE', 'The feasible region is the set of...', '["all possible solutions", "only one solution", "the x-axis", "the objective function"]', 'A', 'Feasible region contains all solutions that satisfy constraints.', FALSE),
((SELECT id FROM topics WHERE code = 'linear-programming'), 'FORM_5', 'MEDIUM', 'OBJECTIVE', 'If profit P = 3x + 2y, the objective is to...', '["factorise", "differentiate", "maximise or minimise", "integrate"]', 'C', 'Linear programming focuses on optimisation.', FALSE),
((SELECT id FROM topics WHERE code = 'linear-programming'), 'FORM_5', 'HARD', 'STRUCTURED', 'A café sells cakes and drinks. Let x and y be quantities. Maximise profit P = 5x + 3y subject to x + y <= 10, x <= 6, y <= 8, x,y >= 0. State the best corner point approach.', NULL, 'Check all corner points of the feasible region: (0,0), (6,0), (6,4), (2,8), (0,8). Evaluate P at each and choose the largest value.', FALSE),
((SELECT id FROM topics WHERE code = 'linear-programming'), 'FORM_5', 'HARD', 'STRUCTURED', 'A school wants to maximise points from products A and B with constraints 2x+y<=12, x+2y<=12, x,y>=0. Explain how to find the optimum.', NULL, 'Draw both constraint lines, identify the feasible region, list the corner points, then substitute each corner point into the objective function to find the maximum or minimum value.', FALSE)
ON CONFLICT DO NOTHING;
