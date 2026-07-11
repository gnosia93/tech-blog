## Java/JVM 벤치마크 스위트 옵션 ##

###  1. SPECjbb2015 — JVM 서버 벤치의 사실상 표준
- 업계 표준. "max-jOPS(처리량)"과 "critical-jOPS(SLA 지연 하 처리량)" 두 지표를 냄 → 처리량 + 지연을 한 번에
- Graviton 관련 벤치마크 글에서 가장 많이 인용되는 게 이것
- 단점: 상용 라이선스(유료). 개인 블로그면 진입장벽

### 2. Renaissance Suite — 무료, 현대적 JVM 벤치마크
- Apache 2.0 라이선스, JAR 하나로 실행. Spark, Netty, 동시성, JIT 등 다양한 워크로드
- 학술·엔지니어 신뢰도 높고 재현 쉬움. 블로그용으로 가장 추천

### 3. DaCapo Benchmark — 무료, 오래된 표준
- 실제 앱 기반(Tomcat, Lucene, H2 등). 최신 23.11-chopin 릴리스가 aarch64 잘 지원
- Renaissance와 함께 쓰면 커버리지 넓어짐

### 4. TechEmpower Framework Benchmarks — 웹 프레임워크 처리량 표준
- 우리가 짠 것과 가장 성격이 유사(REST + DB). Spring 포함 수백 프레임워크 시나리오(JSON/DB query/updates/plaintext)가 이미 구현돼 있음
- "Spring Boot REST API" 시나리오를 직접 안 짜고 그대로 쓸 수 있음 ← 지금 니즈에 딱

### 5. JMH — 마이크로벤치 (앞서 워크로드 A에서 언급)
- 스위트라기보단 하네스. 특정 메서드 수준 측정용
