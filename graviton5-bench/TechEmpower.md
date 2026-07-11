## 테스트 아키텍처 ##
* rds - postgres
* 1 node spring boot
* 1 node k6 ..


## 테스트 대상 ##
* graviton 3, 4, 5
* intel 7, 8 ..

## TechEmpower ##
```
git clone https://github.com/TechEmpower/FrameworkBenchmarks
cd FrameworkBenchmarks
```
* 검증 모드 — 앱이 뜨고 응답이 규격에 맞는지 확인 (부하 X, 빠름)
```
./tfb --mode verify --test spring
```
* 벤치마크 — 부하 생성 + 결과 수집
```
./tfb --mode benchmark --test spring spring-data-jdbc spring-jooq
```

* 특정 타입만
```
./tfb --mode benchmark --test spring --type json db queries
```

* 결과 확인
결과는 results/ 아래 타임스탬프 폴더에 JSON으로 떨어지고, results.json을 tfb 결과 시각화 페이지나 자체 도구로 볼 수 있습니다.
