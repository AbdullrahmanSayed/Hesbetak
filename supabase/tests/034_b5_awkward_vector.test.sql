begin;
create extension if not exists pgtap with schema extensions;
\ir helpers/b1.inc
select no_plan();

--------------------------------------------------------------------------------
-- T23: Awkward vector from spec 8.6
-- cash_total = 1,234,500, down = 200,000, n = 7, factor_bp = 3000, step = 500
-- → financed_base 1,034,500; margin_total round_half_up(310,350) = 310,350
-- → receivable 1,344,850; receivable/7 = 192,121.43 → base_amount 192,500
-- → installments 1–6 = 192,500 (Σ 1,155,000); installment 7 = 189,850
-- Principal/margin per the formula; invariants must hold
--------------------------------------------------------------------------------

-- Test preview with awkward numbers
select is(
  (public.preview_installment_schedule('1234500', '200000', 7, 3000, null, 500, null)->>'financed_base'),
  '1034500',
  'T23 preview: financed_base = 10,345 EGP'
);

select is(
  (public.preview_installment_schedule('1234500', '200000', 7, 3000, null, 500, null)->>'margin_total'),
  '310350',
  'T23 preview: margin_total = 3,103.50 EGP (round_half_up)'
);

select is(
  (public.preview_installment_schedule('1234500', '200000', 7, 3000, null, 500, null)->>'receivable'),
  '1344850',
  'T23 preview: receivable = 13,448.50 EGP'
);

-- Installments 1-6 should be 192,500
select is(
  (public.preview_installment_schedule('1234500', '200000', 7, 3000, null, 500, null)->'schedule'->0->>'amount'),
  '192500',
  'T23 preview: installment 1 = 1,925 EGP'
);
select is(
  (public.preview_installment_schedule('1234500', '200000', 7, 3000, null, 500, null)->'schedule'->5->>'amount'),
  '192500',
  'T23 preview: installment 6 = 1,925 EGP'
);

-- Installment 7 should be 189,850 (remainder)
select is(
  (public.preview_installment_schedule('1234500', '200000', 7, 3000, null, 500, null)->'schedule'->6->>'amount'),
  '189850',
  'T23 preview: installment 7 = 1,898.50 EGP (remainder)'
);

-- Verify sum of amounts = receivable
select is(
  (
    select sum((elem->>'amount')::bigint)::text
    from jsonb_array_elements(
      public.preview_installment_schedule('1234500', '200000', 7, 3000, null, 500, null)->'schedule'
    ) elem
  ),
  '1344850',
  'T23 preview: sum of amounts = receivable'
);

-- Verify sum of principals = financed_base
select is(
  (
    select sum((elem->>'principal')::bigint)::text
    from jsonb_array_elements(
      public.preview_installment_schedule('1234500', '200000', 7, 3000, null, 500, null)->'schedule'
    ) elem
  ),
  '1034500',
  'T23 preview: sum of principals = financed_base'
);

-- Verify sum of margins = margin_total
select is(
  (
    select sum((elem->>'margin')::bigint)::text
    from jsonb_array_elements(
      public.preview_installment_schedule('1234500', '200000', 7, 3000, null, 500, null)->'schedule'
    ) elem
  ),
  '310350',
  'T23 preview: sum of margins = margin_total'
);

-- Verify each installment: amount = principal + margin
select ok(
  (
    select bool_and((elem->>'amount')::bigint = (elem->>'principal')::bigint + (elem->>'margin')::bigint)
    from jsonb_array_elements(
      public.preview_installment_schedule('1234500', '200000', 7, 3000, null, 500, null)->'schedule'
    ) elem
  ),
  'T23 preview: each amount = principal + margin'
);

-- Verify all values are positive
select ok(
  (
    select bool_and(
      (elem->>'amount')::bigint > 0 and
      (elem->>'principal')::bigint >= 0 and
      (elem->>'margin')::bigint >= 0
    )
    from jsonb_array_elements(
      public.preview_installment_schedule('1234500', '200000', 7, 3000, null, 500, null)->'schedule'
    ) elem
  ),
  'T23 preview: all values non-negative'
);

--------------------------------------------------------------------------------
-- Test validation edge cases
--------------------------------------------------------------------------------

-- Zero financed base should fail
select throws_ok(
  $$select public.preview_installment_schedule('100000', '100000', 10, 4000, null, 100, null)$$,
  '22023',
  'المبلغ المؤجل يجب أن يكون أكبر من صفر',
  'Zero financed_base rejected'
);

-- Negative financed base should fail
select throws_ok(
  $$select public.preview_installment_schedule('100000', '200000', 10, 4000, null, 100, null)$$,
  '22023',
  'المبلغ المؤجل يجب أن يكون أكبر من صفر',
  'Negative financed_base rejected'
);

-- Invalid months should fail
select throws_ok(
  $$select public.preview_installment_schedule('1000000', '100000', 0, 4000, null, 100, null)$$,
  '22023',
  'عدد الأقساط يجب أن يكون بين 1 و 60',
  'Zero months rejected'
);
select throws_ok(
  $$select public.preview_installment_schedule('1000000', '100000', 61, 4000, null, 100, null)$$,
  '22023',
  'عدد الأقساط يجب أن يكون بين 1 و 60',
  '61 months rejected'
);

-- Invalid rounding step should fail
select throws_ok(
  $$select public.preview_installment_schedule('1000000', '100000', 10, 4000, null, 200, null)$$,
  '22023',
  'خطوة التقريب يجب أن تكون 100 أو 500 أو 1000 قرش',
  'Invalid rounding step rejected'
);

-- Manual deferred price less than cash price should fail
select throws_ok(
  $$select public.preview_installment_schedule('1000000', '100000', 10, null, '900000', 100, null)$$,
  '22023',
  'السعر الآجل يجب أن يكون أكبر من أو يساوي سعر الكاش',
  'Deferred price < cash price rejected'
);

select * from finish();
rollback;
