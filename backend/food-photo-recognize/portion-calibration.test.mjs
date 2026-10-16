import test from 'node:test';
import assert from 'node:assert/strict';
import { recognize, validateResult, calibratePortions } from './recognition.mjs';

const item = (name, portionCategory, weightSource = 'visual_estimate') => ({
  name, portionCategory, weightSource, preparation: 'cooked',
  grams: 100, minGrams: 80, maxGrams: 150,
  calories: 200, protein: 10, carbs: 30, fat: 4, assumptions: [],
});
const meal = items => ({ isFood: true, name: 'Meal', items, uncertainties: [], clarificationQuestion: null });

test('single request calibrates selected sides while preserving cookies, eggs, chicken and measured rice', async () => {
  const raw = meal([
    item('Рис', 'cooked_grain_or_porridge'),
    item('Гречка', 'cooked_grain_or_porridge'),
    item('燕麦粥', 'cooked_grain_or_porridge'),
    item('Millet porridge', 'cooked_grain_or_porridge'),
    item('Макароны', 'cooked_pasta'),
    item('Картофель', 'potatoes'),
    item('Cookies', 'other'), item('Eggs', 'other'), item('Chicken', 'other'),
    item('Rice weighed by user', 'cooked_grain_or_porridge', 'user_provided'),
    item('Chicken and rice casserole', 'other'),
  ]);
  let calls = 0;
  const output = await recognize({ locale: 'ru', note: 'The weighed rice is 100 g', imageBase64: 'mock' },
    { apiKey: 'mock', model: 'mock', effort: 'medium', timeoutMs: 1000, maxOutputTokens: 4000 },
    async (_url, options) => {
      calls++;
      const request = JSON.parse(options.body);
      const properties = request.text.format.schema.properties.items.items.properties;
      assert.ok(properties.portionCategory.enum.includes('cooked_pasta'));
      assert.ok(properties.weightSource.enum.includes('user_provided'));
      return Response.json({ status: 'completed', output: [{ content: [{ type: 'output_text', text: JSON.stringify(raw) }] }] });
    });
  assert.equal(calls, 1);
  for (const result of output.result.items.slice(0, 6)) {
    assert.equal(result.grams, 70);
    assert.equal(result.minGrams, 56);
    assert.equal(result.maxGrams, 105);
    assert.equal(result.calories, 140);
    assert.equal(result.protein, 7);
    assert.equal(result.carbs, 21);
    assert.ok(Math.abs(result.fat - 2.8) < 1e-10);
  }
  assert.deepEqual(output.result.items.slice(6), raw.items.slice(6));
  assert.equal(output.result.totals.grams, 920);
  assert.equal(output.result.totals.calories, 1840);
  assert.deepEqual(calibratePortions(output.result), output.result);
  assert.equal(raw.items[0].grams, 100);
});

test('legacy results without classification stay unchanged; invalid classification is rejected', () => {
  const legacy = item('Rice', 'cooked_grain_or_porridge');
  delete legacy.portionCategory;
  delete legacy.weightSource;
  assert.equal(calibratePortions(validateResult(meal([legacy]))).totals.grams, 100);
  assert.throws(() => validateResult(meal([item('Rice', 'unknown')])));
  assert.throws(() => validateResult(meal([item('Rice', 'cooked_grain_or_porridge', 'unknown')])));
});
