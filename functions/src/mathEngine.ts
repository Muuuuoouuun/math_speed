export type MathProblem = {
  index: number;
  level: number;
  prompt: string;
  answer: number;
};

class DeterministicRng {
  private state: number;

  constructor(seed: number) {
    this.state = seed === 0 ? 0x6d2b79f5 : seed >>> 0;
  }

  nextInt(maxExclusive: number): number {
    this.state ^= (this.state << 13) >>> 0;
    this.state ^= this.state >>> 17;
    this.state ^= (this.state << 5) >>> 0;
    const value = this.state & 0x7fffffff;
    return maxExclusive === 0 ? 0 : value % maxExclusive;
  }

  between(minInclusive: number, maxInclusive: number): number {
    return minInclusive + this.nextInt((maxInclusive - minInclusive) + 1);
  }
}

export function generateSessionProblems(seed: number, level: number, count: number): MathProblem[] {
  const rng = new DeterministicRng((seed ^ (level * 7919) ^ (count * 104729)) >>> 0);
  return Array.from({ length: count }, (_, index) => buildProblem(rng, level, index));
}

function buildProblem(rng: DeterministicRng, level: number, index: number): MathProblem {
  switch (level) {
    case 1:
      return singleDigitAdd(rng, level, index);
    case 2:
      return within20Mix(rng, level, index);
    case 3:
      return twoDigitMix(rng, level, index);
    case 4:
      return carryPlusTable(rng, level, index);
    case 5:
      return tableMultiplication(rng, level, index);
    case 6:
      return exactDivision(rng, level, index);
    case 7:
      return twoStepMixed(rng, level, index);
    case 8:
      return threeNumberMixed(rng, level, index);
    case 9:
      return multiMultiplyDivide(rng, level, index);
    default:
      return bossRound(rng, level, index);
  }
}

function singleDigitAdd(rng: DeterministicRng, level: number, index: number): MathProblem {
  const a = rng.between(1, 9);
  const b = rng.between(1, 9);
  return { index, level, prompt: `${a} + ${b}`, answer: a + b };
}

function within20Mix(rng: DeterministicRng, level: number, index: number): MathProblem {
  const add = rng.nextInt(2) === 0;
  if (add) {
    const a = rng.between(3, 15);
    const b = rng.between(1, 20 - a);
    return { index, level, prompt: `${a} + ${b}`, answer: a + b };
  }

  const a = rng.between(8, 20);
  const b = rng.between(1, a - 1);
  return { index, level, prompt: `${a} - ${b}`, answer: a - b };
}

function twoDigitMix(rng: DeterministicRng, level: number, index: number): MathProblem {
  const add = rng.nextInt(2) === 0;
  if (add) {
    const a = rng.between(11, 59);
    const b = rng.between(11, 39);
    return { index, level, prompt: `${a} + ${b}`, answer: a + b };
  }

  const a = rng.between(30, 99);
  const b = rng.between(10, a - 5);
  return { index, level, prompt: `${a} - ${b}`, answer: a - b };
}

function carryPlusTable(rng: DeterministicRng, level: number, index: number): MathProblem {
  if (rng.nextInt(3) === 0) {
    const a = rng.between(2, 9);
    const b = rng.between(3, 9);
    return { index, level, prompt: `${a} × ${b}`, answer: a * b };
  }

  const a = rng.between(28, 87);
  const b = rng.between(15, 38);
  return { index, level, prompt: `${a} + ${b}`, answer: a + b };
}

function tableMultiplication(rng: DeterministicRng, level: number, index: number): MathProblem {
  const a = rng.between(3, 12);
  const b = rng.between(3, 12);
  return { index, level, prompt: `${a} × ${b}`, answer: a * b };
}

function exactDivision(rng: DeterministicRng, level: number, index: number): MathProblem {
  const divisor = rng.between(2, 12);
  const quotient = rng.between(2, 12);
  const dividend = divisor * quotient;
  return { index, level, prompt: `${dividend} ÷ ${divisor}`, answer: quotient };
}

function twoStepMixed(rng: DeterministicRng, level: number, index: number): MathProblem {
  const left = rng.between(2, 9);
  const right = rng.between(2, 9);
  const tail = rng.between(5, 40);
  const multiplyFirst = rng.nextInt(2) === 0;

  if (multiplyFirst) {
    return { index, level, prompt: `(${left} × ${right}) + ${tail}`, answer: (left * right) + tail };
  }

  return { index, level, prompt: `${tail} + ${left} - ${right}`, answer: tail + left - right };
}

function threeNumberMixed(rng: DeterministicRng, level: number, index: number): MathProblem {
  const a = rng.between(15, 99);
  const b = rng.between(5, 39);
  const c = rng.between(3, 25);
  const addLast = rng.nextInt(2) === 0;
  const answer = addLast ? (a - b) + c : (a + b) - c;
  const prompt = addLast ? `${a} - ${b} + ${c}` : `${a} + ${b} - ${c}`;
  return { index, level, prompt, answer };
}

function multiMultiplyDivide(rng: DeterministicRng, level: number, index: number): MathProblem {
  const a = rng.between(3, 12);
  const b = rng.between(3, 12);
  const c = rng.between(2, 6);
  return { index, level, prompt: `(${a} × ${b}) ÷ ${c}`, answer: Math.trunc((a * b) / c) };
}

function bossRound(rng: DeterministicRng, level: number, index: number): MathProblem {
  const a = rng.between(12, 29);
  const b = rng.between(4, 12);
  const c = rng.between(3, 9);
  const d = rng.between(10, 49);
  return { index, level, prompt: `(${a} × ${b}) - (${c} × ${d})`, answer: (a * b) - (c * d) };
}
