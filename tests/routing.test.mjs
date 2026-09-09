import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import vm from 'node:vm';

// Exercise the actual deployed source with the CloudFront helper stubbed.
// This checks routing decisions, not AWS's network failover implementation.
const source = readFileSync(new URL('../modules/web-tier/balance.js', import.meta.url), 'utf8')
  .replace(/^import cf from "cloudfront";\s*/, '');

for (const [random, expectedOrder] of [
  [0, ['web-a', 'web-b']],
  [0.499999, ['web-a', 'web-b']],
  [0.5, ['web-b', 'web-a']],
  [0.999999, ['web-b', 'web-a']],
]) {
  test(`routes both origins and retains failover at random=${random}`, () => {
    const groups = [];
    const request = { method: 'GET', uri: '/', headers: {} };
    const result = vm.runInNewContext(`${source}\nhandler(event);`, {
      cf: { createRequestOriginGroup: group => groups.push(JSON.parse(JSON.stringify(group))) },
      Math: { random: () => random },
      event: { request },
    });
    assert.equal(result, request);
    assert.equal(groups.length, 1);
    assert.deepEqual(groups[0].originIds, expectedOrder);
    assert.deepEqual(groups[0].failoverCriteria.statusCodes, [500, 502, 503, 504]);
  });
}
