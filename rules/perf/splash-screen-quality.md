---
id: perf/splash-screen-quality
severity: observation
category: perf
applies-to:
  - app/src/main/java
  - app/src/main/res
since: "2.11.0"
---

# Якість сплеш-скріна (наявність, анімація, тематичність)

## Інваріант

Апка має сплеш-скрін, який: (1) **існує**, (2) **анімований** — містить
брендований рух, а не статичну картинку чи голий системний спінер,
(3) **відповідає тематиці гри/апки** — перше враження заохочує
користувача лишитись, а не виглядає як чужий або порожній екран.

Це **observation**-правило: ніколи не блокує реліз. Сплеш — UX-якість,
не функціональний контракт.

## Як перевірити

1. **Наявність.** Знайти реалізацію сплеша — каталог відомих
   механізмів (extensible, не exhaustive):
   - **SplashScreen API**: `Theme.SplashScreen` у `res/values/themes*.xml`,
     `installSplashScreen()` у launcher Activity,
     `windowSplashScreenAnimatedIcon`.
   - **Кастомний Compose-екран**: route/composable з назвою
     `Splash*` / `Loading*` / `Loader*`, який показується **першим**
     у NavHost і навігує далі (`LaunchedEffect` + `navigate`).
   - **Lottie**: залежність `lottie-compose`/`lottie` +
     `LottieAnimation(...)` + `res/raw/*.json`.
   - **AnimationDrawable / AnimatedVectorDrawable**:
     `res/drawable/*.xml` із `<animation-list>` або `<animated-vector>`,
     підключений до стартового екрана.
   - **Відео-сплеш**: ExoPlayer/`VideoView` на стартовому екрані.

   Якщо стартовий екран апки — одразу гра/контент без жодного з
   механізмів вище і без аналога → сплеш **відсутній**.

2. **Анімованість** — dataflow, не назви файлів. Простежити, що саме
   рендерить стартовий екран:
   - **Анімований**: Lottie / AVD / animation-list / відео;
     Compose-анімації (`rememberInfiniteTransition`,
     `animate*AsState`, `Animatable` з рухом logo/елементів);
     View-анімації (`ObjectAnimator`, `startAnimation`).
   - **НЕ анімований**: статична `Image`/`ImageView` + `delay()`;
     голий системний `CircularProgressIndicator`/`ProgressBar` без
     брендованого руху (системний спінер сам по собі — не сплеш-анімація).

3. **Тематичність** — judgment call агента (допустимо, бо severity =
   observation). Зіставити вміст сплеша з тематикою апки:
   - тематика апки: `app_name` у `strings.xml`, назви ігрових
     екранів/асетів, домен гри (фрукти, зомбі, головоломка...);
   - вміст сплеша: назви drawable/raw-асетів, шари Lottie-JSON
     (`layers[].nm`), кольорова палітра, текст/логотип на сплеші.

   Приклад: гра про фрукти → сплеш із фруктами/соковитими кольорами =
   тематичний; білий екран із системним спінером або логотип, що не
   стосується гри, = нетематичний.

4. Емітити **рівно один** finding за пріоритетом проблеми:
   **відсутній > статичний > нетематичний**. Якщо все гаразд —
   додати у «Перевірені інваріанти» з one-line описом, який механізм
   сплеша знайдено.

## Як виглядає поломка

```kotlin
// Стартовий екран: статична картинка + delay — не анімований сплеш
@Composable
fun SplashScreen(onDone: () -> Unit) {
    LaunchedEffect(Unit) { delay(2000); onDone() }
    Box(Modifier.fillMaxSize().background(Color.White)) {
        CircularProgressIndicator(Modifier.align(Alignment.Center))  // ❌ голий системний спінер
    }
}
```

## Як виглядає правильно

```kotlin
// Lottie-анімація у тематиці гри (фрукти) + навігація далі
@Composable
fun SplashScreen(onDone: () -> Unit) {
    val composition by rememberLottieComposition(
        LottieCompositionSpec.RawRes(R.raw.fruit_splash)   // ✅ тематичний анімований асет
    )
    val progress by animateLottieCompositionAsState(composition)
    LaunchedEffect(progress) { if (progress == 1f) onDone() }
    LottieAnimation(composition, { progress }, Modifier.fillMaxSize())
}
```

## Як доповідати

**OBSERVATION** — сплеш відсутній:
```
[perf/splash-screen-quality] OBSERVATION
  (decentralized — see notes)
  Сплеш-скрін відсутній: стартовий екран апки — одразу <що саме>, жодного splash-механізму (SplashScreen API / Compose splash / Lottie / AVD / відео) не знайдено. Перше враження без брендованого входу гірше утримує користувача.
  Як виправити: додайте анімований сплеш у тематиці гри — напр. Lottie-анімацію (res/raw/*.json) на стартовому route перед основним екраном.
  Див.: https://developer.android.com/develop/ui/views/launch/splash-screen
```

**OBSERVATION** — сплеш є, але статичний:
```
[perf/splash-screen-quality] OBSERVATION
  <file>:<line>
  Сплеш-скрін статичний: <опис — напр. статична Image + delay(2000), системний спінер>. Брендованого руху немає — екран виглядає як заглушка.
  Як виправити: анімуйте сплеш — Lottie/AnimatedVectorDrawable/Compose-анімація логотипа у тематиці гри.
  Див.: https://developer.android.com/develop/ui/views/launch/splash-screen
```

**OBSERVATION** — сплеш анімований, але не відповідає тематиці:
```
[perf/splash-screen-quality] OBSERVATION
  <file>:<line>
  Сплеш-скрін не відповідає тематиці апки: апка про <тематика — напр. фруктову гру>, а сплеш показує <що саме — напр. абстрактний спінер/чужий логотип/нейтральний градієнт>. Перше враження не пов'язане з контентом.
  Як виправити: замініть асет сплеша на тематичний (<підказка з асетів гри>), щоб вхід в апку відповідав її контенту.
  Див.: https://developer.android.com/develop/ui/views/launch/splash-screen
```

## Виключення

Дозволено через `accepted-deviations` з явною причиною — наприклад,
вимога замовника «без сплеша», text-only утиліта без ігрового
контенту, чи сплеш свідомо мінімалістичний за бренд-гайдом. Формат:
`perf/splash-screen-quality: <причина>`.
