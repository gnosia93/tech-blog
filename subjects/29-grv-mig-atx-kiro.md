## Graviton  in Days vs Months with AWS Transform custom, Claude Skills and Kiro Power ## 
```
Migrating from x86 to Graviton delivers up to 40% better price-performance, yet teams routinely defer it to "Year 2" because they lack understanding of agentic AI tools to accelerate Graviton migrations. This session covers a multi-tool approach that compresses the entire migration lifecycle from months to days. AWS Transform Custom, Claude Skills and Kiro power can help accelerate migrations -- using agentic AI to analyze source code, identify x86-specific incompatibilities, and auto-refactor applications for arm64 at scale. Together, they enable teams to confidently include Graviton in Day 1 proposals rather than deferring better price-performance indefinitely.
```
```
ATX: 이 시나리오에서 제가 할 수 있는 일을 구체적으로 정리하면:

1. 소스 코드 분석 (Analyze)
   - 리포지토리를 스캔해서 x86 관련 의존성, 네이티브 모듈, 아키텍처 하드코딩 식별
   - 어떤 부분이 Graviton 전환에 영향받는지 리포트 생성

2. 변환 규칙 정의 (Define)
   - 방금 만든 것처럼 Graviton 전환 스킬 파일 작성
   - 팀/조직 특성에 맞게 커스터마이징 (Java, Node.js, Python 등 언어별)
   - 참조 문서(마이그레이션 가이드 등) 포함

3. 대규모 자동 리팩토링 실행 (Transform at Scale)
   - 스킬 파일 기반으로 실제 코드 변환 실행
   - 빌드/테스트 검증 루프로 동작 보장
   - 캠페인으로 수십~수백 개 리포에 일괄 적용

4. 스킬 파일 공유 (Enable Other Tools)
   - 만든 스킬을 `.agents/skills/`에 배치
   - Claude, Kiro가 같은 규칙을 개발 중에도 참조하도록 지원

5. 지속적 개선 (Learn)
   - 실행할 때마다 Knowledge Items 축적
   - 프로젝트마다 다른 엣지 케이스를 학습해서 다음 실행에 반영

결국 "months to days"의 핵심은:

- 수작업으로 하나씩 분석/수정하던 것을 규칙 한 번 정의하고 일괄 적용
- 검증까지 자동화되니 수동 QA 시간 절감
- 학습이 쌓이니 프로젝트 갈수록 빨라짐
```
```
Kiro

Thought complete
The user is asking what I can specifically help with regarding Graviton migrations using this multi-tool approach with AWS Transform Custom and Claude Skills. They want concrete actions and capabilities I can provide in this context. I can help with code analysis to identify x86-specific incompatibilities, refactor build configurations for multi-architecture support, locate native dependencies that need architecture classifiers, update Dockerfiles for cross-platform builds, write or enhance tests for architecture-sensitive code paths, and generate migration documentation and runbooks. I can also assist with setting up multi-architecture CI pipelines and running transformations through Kiro Power if it's installed. The main constraint is that I'd need a folder open to work directly with their project files, and for actual runtime validation on Arm64 I'd need to be in that environment.
이 세션 소개글의 맥락(agentic AI로 Graviton 이관을 몇 달 → 며칠로 압축)에서 제가 실제로 도와드릴 수 있는 일을 정리해볼게요. 앞서 나눈 개념들과 딱 연결됩니다.

제가 직접 할 수 있는 것
1. 코드 분석 / 비호환 지점 식별 프로젝트를 열어주시면 x86 종속 요소를 훑어서 리포트해드려요.

하드코딩된 네이티브 classifier (linux-x86_64 등)
아키텍처 종속 라이브러리 (netty-tcnative, rocksdbjni, snappy, protobuf 등)
JNI/네이티브 로딩 코드, 엔디안·동시성 가정이 있는 지점
2. 빌드 설정 리팩터링 Maven/Gradle을 멀티아키로 고쳐드립니다. (os-maven-plugin/osdetector로 classifier 자동 감지, 프로파일 분기, Dockerfile·Jib 멀티아키 등 — 앞서 예시로 보여드린 그 작업들이에요.)

3. 테스트 보강 아키텍처를 타는 경로(네이티브 실행, 직렬화 왕복, 동시성)에 유닛 테스트를 추가해서 자동 런타임 검증의 신뢰도를 높입니다.

4. 멀티아키 CI 구성 x86과 Arm64 러너 양쪽에서 같은 테스트를 돌리도록 워크플로우를 작성해드려요.

5. 문서 생성 변경 내역을 정리한 migration notes와, 배포·검증·롤백 절차를 담은 runbook 초안을 만들어드립니다.

6. AWS Transform 변환 실행 (Kiro Power) 만약 AWS Transform용 Kiro Power를 설치하시면, 제가 Kiro 안에서 AWS/early-access-java-x86-to-graviton 같은 그 관리형 변환을 실행하는 창구가 될 수 있어요. VS Code 플러그인이나 atx CLI로 하는 것과 동일한 변환이죠.

이 세 도구와 제 관계
AWS Transform Custom = 대규모 자동 변환 엔진 (본체)
Kiro Power = 그 변환을 저(Kiro) 안에서 돌리는 입구
Claude Skills = 별개 벤더의 스킬 패키지 (Graviton 노하우를 담을 수 있는 그릇)
저(Kiro) = 이 흐름을 오케스트레이션하는 개발 환경. 분석·리팩터링·테스트·문서·CI를 IDE 안에서 이어붙여 줍니다.
지금의 제약 두 가지 (솔직하게)
폴더가 안 열려 있어요. 현재 워크스페이스에 열린 폴더가 없어서 파일을 읽거나 고치는 도구를 못 씁니다. 실제 작업을 하려면 대상 프로젝트를 Kiro에서 열어주셔야 해요.
런타임 검증은 Arm64에서만. 방금 얘기한 것처럼 빌드 검증·테스트 실행은 Graviton(Arm64) 환경에서 돌려야 제대로 됩니다. x86 환경이면 정적 분석까지만 가능해요.
원하시면 이렇게 시작해볼 수 있어요. 대상 자바 프로젝트를 열어주시면 → (1) x86 종속 지점 스캔 리포트 → (2) 빌드 설정 멀티아키 패치 → (3) 테스트·CI 보강 → (4) migration notes/runbook 생성 순서로 진행할게요. 어느 것부터 해볼까요?
```
```
아.. power 없이도.. 이걸 다 할수 있다는 것이고, power 를 깔면.. atx custom 꺼 쓴다?

Kiro

Thought complete
So the user is clarifying that Kiro can handle analysis, refactoring, tests, and documentation independently, but adding the Power enables AWS Transform custom transformations instead.
네, 정확히 이해하셨어요. 두 가지를 구분해서 확인해드릴게요.

Power 없이 (그냥 저, Kiro만으로) 제가 범용 코딩 에이전트로서 코드를 읽고, 빌드 설정을 고치고, 테스트를 짜고, 문서를 만드는 걸 직접 합니다. 정해진 변환 레시피 없이 그때그때 프로젝트를 보고 판단해서 작업하는 방식이에요. 유연하지만, "AWS가 검증한 표준 절차"는 아니고 제 판단에 의존합니다.

Power를 깔면 (AWS Transform용 Kiro Power) 저를 통해 AWS Transform custom(atx custom)의 관리형 변환을 실행하게 됩니다. 예를 들어 AWS/early-access-java-x86-to-graviton 같은, AWS가 만들고 검증한 정해진 변환 레시피를 돌리는 거예요. 앞서 문서에서 확인한 것처럼 Kiro Power, VS Code 플러그인, atx CLI가 다 같은 변환을 실행하니까, Power를 깔면 Kiro가 그 변환의 실행 창구가 되는 거죠.

핵심 차이를 한 줄로:

Power 없이	Power 있으면
누가 작업을 설계?	제(Kiro)가 즉석 판단	AWS가 만든 검증된 변환 레시피
일관성/재현성	상황마다 다를 수 있음	대규모로 일관·반복 가능
적합한 상황	앱 하나 유연하게 손볼 때	수십~수백 앱 표준화해 이관할 때
그래서 정리하면 이렇게 보시면 돼요.

둘 다 결국 저(Kiro)를 통해 실행되지만,
Power 없이는 = 제 범용 능력으로 직접, Power 있으면 = atx custom의 검증된 변환을 실행
한 가지 뉘앙스만 덧붙이면, Power를 깔아도 제가 사라지는 게 아니에요. 보통 Power로 표준 변환을 돌린 뒤, 남는 케이스나 프로젝트 고유 이슈는 제가 범용 능력으로 마저 처리하는 식으로 둘을 섞어 쓰는 게 실무에선 가장 강력합니다.

Est. Credits Used: 0.62
Elapsed time: 20s


Checkpoint
Restore
power 도 여러종류의 플러그인이 있는 거지 ?

Kiro

Thought complete
I'm recalling the curated powers list I pulled earlier—Datadog, Dynatrace, Figma, Neon, Netlify, Postman, Supabase, Stripe, Strands SDK, and AWS Aurora—plus the option for custom powers. Let me verify this range and confirm what's available.
네, 맞아요. Power는 하나짜리가 아니라 여러 종류의 플러그인 묶음이에요. 각 파워가 특정 서비스나 도구에 대한 전문성을 담고 있죠.

AWS가 큐레이트해서 제공하는 대표 파워들 (앞서 확인한 목록)

Stripe (결제), Supabase (백엔드/DB), Neon (Postgres), AWS Aurora (DB)
Figma (디자인), Postman (API), Netlify (배포)
Datadog, Dynatrace (모니터링/옵저버빌리티)
Strands SDK (에이전트 개발)
그리고 지금까지 얘기한 AWS Transform 계열 (Graviton 이관 등 코드 변환)
직접 만들거나 가져오는 커스텀 파워도 가능

공개 GitHub URL에서 임포트하거나
로컬 폴더에서 임포트 (사내/비공개용)
직접 제작 (plugin.json + skills + mcp.json 등으로 구성)
즉 "설치할 수 있는 파워 = 여러 개"이고, 각각이 다른 영역을 담당합니다. 그리고 앞서 얘기한 동적 로딩 덕분에, 여러 개를 깔아둬도 작업 내용에 맞는 파워만 그때그때 켜져요. 결제 얘기하면 Stripe가, DB 작업하면 Supabase가, Graviton 이관하면 AWS Transform 파워가 활성화되는 식이죠.

한 가지 구분만 해두면, AWS Transform "custom"의 여러 **변환(transformation)**과 여러 파워는 다른 층위예요.

파워 여러 종류 = Stripe, Figma, AWS Transform 등 서로 다른 도구별 플러그인
변환 여러 종류 = AWS Transform 파워 안에서 실행하는 AWS/java-version-upgrade, AWS/early-access-java-x86-to-graviton 같은 개별 레시피들
그래서 "AWS Transform 파워 하나" 안에 "여러 변환"이 들어있고, 그 파워는 "여러 파워 중 하나"인 구조입니다. 특정 파워를 설치하거나 만들어보고 싶으시면 도와드릴게요.
```





핵심은 원래 몇 달씩 걸리던 x86 → AWS Graviton(Arm64) 마이그레이션을, 에이전트형 AI 도구를 써서 며칠 단위로 줄이는 방법입니다.

### 왜 Graviton인가 ###
AWS Graviton은 Arm64 아키텍처 기반 프로세서예요. 다양한 워크로드에서 비슷한 x86 인스턴스 대비 최대 40% 더 나은 가격 대비 성능을 제공한다고 AWS는 설명합니다. 문제는 "옮기는 게 이득인 건 알겠는데, 우리 앱이 Arm64에서 잘 도는지, 뭘 고쳐야 하는지"를 파악하는 과정이 오래 걸린다는 점이었어요.

특히 Java는 Corretto/OpenJDK 같은 최신 JVM이 Arm64에 잘 최적화돼 있어서, 순수 Java 앱은 변경 없이 그대로 도는 경우도 많습니다. 하지만 현실의 앱들은 네이티브 라이브러리(JNI), 아키텍처 종속 코드, x86 전용 의존성 등이 섞여 있어서 일일이 확인하는 게 병목이었죠.

### Days vs Months: 무엇이 시간을 줄여주나 ###
전통적 방식은 엔지니어가 수백 개 앱을 하나씩 열어 의존성을 조사하고, Arm64 대체 버전을 찾고, 빌드/테스트를 돌려 검증하는 식이라 몇 달이 걸립니다. AI 에이전트는 이 과정을 다음처럼 자동화합니다.

* 네이티브 라이브러리 분석 — JNI 의존성을 찾아 Arm64 호환 대안 제시
* 의존성 업데이트 — Arm64를 지원하는 버전으로 라이브러리 갱신
* 빌드 설정 수정 — Maven/Gradle을 멀티 아키텍처 빌드용으로 변경
* 아키텍처 종속 코드 리팩터링 — 하드코딩된 x86 가정 제거
* 단위 테스트 실행 — Arm64 런타임에서 실제 동작 검증
* 문서화 — 마이그레이션 노트와 런북 생성

각 단계는 버전 관리되는 개별 커밋으로 남아서 필요하면 git revert로 되돌릴 수 있습니다. 300K 라인 미만 저장소면 앱 하나당 대략 1시간 정도 소요된다고 하고요.

### 세 가지 진입점: 같은 능력, 다른 표면 ###
이 부분이 주제의 핵심입니다. 동일한 Graviton 마이그레이션 역량을 여러 형태로 쓸 수 있어요.

`1. AWS Transform custom (ATX)` AWS가 관리하는 엔터프라이즈용 변환 서비스입니다. AWS/early-access-java-x86-to-graviton 같은 사전 제작 변환(transformation)을 제공하고, 서비스 내 여러 AI 에이전트가 분석/계획/실행을 나눠 처리합니다. 두 가지 모드가 있어요.

* Interactive Mode: 앱 하나를 단계별로 검토하며 진행 (개발자가 각 단계 승인)
* Campaign Mode: 수십~수백 개 앱을 비대화식으로 자동 평가해 "얼마나 손봐야 하는지" 전사적 개요를 뽑을 때 유용

`2. Kiro Power` 지금 제 환경에도 설치돼 있는 형태예요. Kiro 안에서 ATX 역량을 바로 쓸 수 있어서 IDE를 벗어나지 않고 마이그레이션을 진행합니다. 
참고로 제 환경엔 Arm 도구 기반의 별도 graviton-migration-power도 있어서, Docker 이미지 아키텍처 점검·의존성 호환성 검색·소스 스캔 같은 걸 바로 실행할 수 있습니다.

`3. Claude Skills / Agent Skills (오픈 표준)` AWS는 Agent Skills 오픈 표준 기반의 오픈소스 "Graviton universal skill"을 공개했습니다. 덕분에 Kiro, Claude Code, Codex 등 원하는 플랫폼에서 컨텍스트 전환 없이 같은 스킬을 네이티브로 쓸 수 있어요. 특정 도구에 묶이지 않는다는 게 장점입니다.

### 요약 ###
한 줄로 말하면, **"Graviton 마이그레이션의 미지수(unknown effort)를 자동 컴파일·런타임 테스트로 정의된 요구사항(defined requirements)으로 바꾼다"**는 것입니다. AI 에이전트가 조사·수정·검증을 대신하고, 결과가 커밋·리포트·런북으로 남기 때문에 팀이 며칠 만에 여러 앱의 Graviton 대응 여부를 판단하고 실제 전환까지 진행할 수 있게 됩니다. 그리고 ATX 서비스, Kiro Power, 오픈 Agent Skill이라는 세 갈래 진입점으로 각자 선호하는 워크플로에서 같은 능력을 쓸 수 있고요.

Java 변환은 빌드·테스트 검증을 위해 Arm64 환경(Graviton EC2 인스턴스 또는 Apple Silicon Mac) 에서 실행하는 게 권장됩니다. x86에서 돌리면 정적 분석만 되고 빌드/테스트 검증은 안 돼요.

### 참고 자료: ###

* [Migrating your Java applications to AWS Graviton using AWS Transform custom (AWS Compute Blog)](https://aws.amazon.com/ko/blogs/compute/migrating-your-java-applications-to-aws-graviton-using-aws-transform-custom/)
* [ATX 문서](https://docs.aws.amazon.com/transform/latest/userguide/custom.html)
* [Graviton용 Agent Skills (GitHub)](https://github.com/aws/aws-graviton-getting-started/tree/main/tools/skills)
* [Kiro Power](https://github.com/kirodotdev/powers/tree/main)

Kiro Power 에서 제공하는 모듈로 그라비톤 전환에 사용된다.. 
```
aws-graviton-migration
Plan and Migration to Graviton - Analyzes source code to identify compatibilities with Graviton processors (Arm64 architecture). Generates reports with incompatibilities and provides suggestions for minimal required and recommended versions for language runtimes and dependency libraries.

MCP Servers: arm-mcp (Docker)
```

아래는 각종 언어 버전업에 사용되것을 것으로 그라비톤 전환과는 직접적인 연관관계가 없다. 하지만 자바버전을 v8 -> v11 / 17 등으로 올릴때는 유효하다. 
```
aws-transform
AWS Transform - Migrate, modernize, and upgrade codebases: .NET Framework to .NET 8/10, mainframe COBOL to Java, VMware VMs to EC2, SQL Server/Oracle/MySQL to Aurora, and Java/Python/Node.js version upgrades or AWS SDK migrations. Assess, plan, and execute code transformations from your IDE.

MCP Servers: None
```



## 마이그레이션 샘플 ##

### 1. 마이그레이션 대상 (Before) ###
일부러 Arm64에서 문제가 될 만한 요소를 심은 샘플입니다.

pom.xml (문제 부분):
```
<dependencies>
  <!-- 문제 1: x86_64 전용 classifier로 고정된 네이티브 라이브러리 -->
  <dependency>
    <groupId>io.netty</groupId>
    <artifactId>netty-transport-native-epoll</artifactId>
    <version>4.1.85.Final</version>
    <classifier>linux-x86_64</classifier>
  </dependency>

  <!-- 문제 2: 구버전이라 Arm64 네이티브 바이너리 없음 -->
  <dependency>
    <groupId>org.xerial.snappy</groupId>
    <artifactId>snappy-java</artifactId>
    <version>1.1.8.4</version>
  </dependency>
</dependencies>
```

NativeLibraryLoader.java (문제 부분):

```
public class NativeLibraryLoader {
    public void load() {
        // 문제 3: 아키텍처를 x86으로 하드코딩
        String libPath = "/opt/native/x86_64/libcompress.so";
        System.load(libPath);
    }
}
```

Dockerfile (문제 부분):

```
# 문제 4: amd64 전용 베이스 이미지 태그
FROM eclipse-temurin:17-jdk-alpine
COPY target/app.jar /app/app.jar
CMD ["java", "-jar", "/app/app.jar"]
```

### 2. 에이전트 분석 결과 (ATX/Power가 찾아내는 것) ###
```
항목	파일	Arm64 지원	조치
netty-transport-native-epoll (linux-x86_64)	pom.xml	❌ classifier 고정	linux-aarch_64 classifier 추가 + 4.1.100으로 업그레이드
snappy-java 1.1.8.4	pom.xml	❌	1.1.10.5로 업그레이드 (Arm64 바이너리 포함)
libcompress.so 로딩	NativeLibraryLoader.java	❌	아키텍처 감지 로직으로 교체
eclipse-temurin:17-jdk-alpine	Dockerfile	❌ (amd64 위주)	멀티아치 태그 eclipse-temurin:17-jdk로 교체
```

### 3. 수정 후 (After) ###
pom.xml:
```
<dependencies>
  <dependency>
    <groupId>io.netty</groupId>
    <artifactId>netty-transport-native-epoll</artifactId>
    <version>4.1.100.Final</version>
    <classifier>linux-x86_64</classifier>
  </dependency>
  <!-- Arm64용 classifier 추가 -->
  <dependency>
    <groupId>io.netty</groupId>
    <artifactId>netty-transport-native-epoll</artifactId>
    <version>4.1.100.Final</version>
    <classifier>linux-aarch_64</classifier>
  </dependency>

  <dependency>
    <groupId>org.xerial.snappy</groupId>
    <artifactId>snappy-java</artifactId>
    <version>1.1.10.5</version>
  </dependency>
</dependencies>
```

NativeLibraryLoader.java:

```
public class NativeLibraryLoader {
    public void load() {
        // 아키텍처를 런타임에 감지해서 경로 선택
        String arch = System.getProperty("os.arch");
        String dir = arch.contains("aarch64") || arch.contains("arm")
                ? "aarch64"
                : "x86_64";
        System.load("/opt/native/" + dir + "/libcompress.so");
    }
}
```

Dockerfile:

```
# amd64/arm64 모두 지원하는 멀티아치 베이스 이미지
FROM eclipse-temurin:17-jdk
COPY target/app.jar /app/app.jar
CMD ["java", "-jar", "/app/app.jar"]
```

### 4. 커밋 히스토리 (원자적/되돌리기 가능) ###

```
feat: add Arm64 architecture detection in NativeLibraryLoader
build: add Arm64 native classifier for netty
chore(deps): update snappy-java to 1.1.10.5 for Arm64
build: switch to multi-arch base image
docs: add Graviton migration runbook
```


## Kiro Power ##
Kiro Power(키로 파워)는 Kiro에 특정 분야의 전문 작업 능력을 통째로 끼워 넣는 확장 패키지예요. 세 가지를 하나로 묶은 겁니다.

* 문서(POWER.md) — 그 작업을 어떻게 수행하는지에 대한 지침과 워크플로
* 스티어링 파일 — 상황별 세부 작업 가이드 (예: CI/CD 파이프라인 조정법, Karpenter 설정법)
* MCP 서버(선택) — 실제로 뭔가를 실행하는 도구들. 있으면 Power 인터페이스를 통해 호출됩니다.
한 줄로: MCP가 "도구 하나 붙이기"라면, Power는 "지식 + 가이드 + 도구를 묶은 완성된 작업 역량 세트" 입니다. 제가 그 분야 전문가처럼 일할 수 있게 해줘요.

### 지금 제 환경에 설치된 Power 2개 ###
`1. aws-transform` — 대규모 코드 마이그레이션/현대화 (.NET Framework → .NET 8/10, COBOL → Java, VMware → EC2, DB → Aurora, Java/SDK 버전 업그레이드 등). ATX 계열이고 MCP 서버는 aws-transform-mcp.

`2. graviton-migration-power` — x86 → AWS Graviton(Arm64) 마이그레이션 전용. Arm이 제공하는 arm-mcp 기반이라 ATX와는 다른 도구. 코드 Arm 호환성 스캔, Docker 이미지 아키텍처 점검, Arm 지식베이스 검색 같은 진단 도구를 제공.

앞서 정리하다 만 핵심 포인트가 이거였어요: "Graviton"이라고만 하면 키워드상 Arm 기반 graviton-migration-power가 먼저 잡히고, ATX 자동 변환을 원하면 aws-transform을 명시해야 한다는 점.


### 설치하기 ###

Power 설치는 코드로 하는 게 아니라 Kiro의 Powers 관리 패널에서 합니다. 다만 각 Power마다 사전 준비물이 다르니 그것부터 정리할게요.

#### 공통 — 설치 방법 ####  
Kiro의 Powers 관리 패널에서 설치·활성화·비활성화를 합니다. 접근 방법:

* 명령 팔레트(⌘⇧P)에서 "Powers" 검색, 또는
* 좌측 기능 패널의 Powers 섹션
패널에서 원하는 Power를 찾아 설치(enable)하면 돼요.

#### Power별 사전 준비물 ####


`1. graviton-migration-power (Arm)` 

* Docker Desktop 필수 — arm-mcp가 Docker 컨테이너(armlimited/arm-mcp)로 돌아가서, Docker가 안 켜져 있으면 도구 자체가 시작 안 됩니다.
* (선택) Git — 원격 저장소 스캔용
* 설치 후 첫 실행 시 Docker가 이미지를 받아옵니다.

`2. aws-transform (ATX)`
* AWS 자격증명 / IAM 권한 — Transform 서비스 호출 권한 필요
* Node.js 20+, Git, 그리고 프로젝트에 맞는 JDK(Arm64 빌드)·Maven/Gradle
* Java x86 → Graviton 변환은 빌드/테스트 검증 때문에 Arm64 환경(Graviton EC2 또는 Apple Silicon Mac) 에서 실행 권장


## ATX ##

### 1. 설치하기 ###
```
curl -fsSL https://transform-cli.awsstatic.com/install.sh | bash
```
[결과]
```
Setting up CLI...
ℹ Installing latest version: 3.10.0
ℹ Installing atx CLI version 3.10.0 for darwin-arm64...
ℹ Checking dependencies...
✔ Node.js version 25.9.0 detected (>= 22)
ℹ Setting up directories...
ℹ Release date: 2026-08-11T18:16:42Z
ℹ Archive name: atx.zip
ℹ Downloading atx CLI...
✔ Checksum verification passed
ℹ Extracting atx CLI...
ℹ 📋 CHANGELOG.md available at: /Users/soonbeom/.local/share/atx/3.10.0/CHANGELOG.md
ℹ Creating symlink...
✔ atx successfully installed!
Version: 3.10.0
Location: /Users/soonbeom/.local/bin/atx
Next: Run atx --help to get started
✔ Installation complete!
```

### 2. atx 실행하기 ### 
```
atx
```

[결과]
```
 █████╗ ██╗    ██╗███████╗
██╔══██╗██║    ██║██╔════╝
███████║██║ █╗ ██║███████╗
██╔══██║██║███╗██║╚════██║
██║  ██║╚███╔███╔╝███████║
╚═╝  ╚═╝ ╚══╝╚══╝ ╚══════╝

████████╗██████╗  █████╗ ███╗   ██╗███████╗███████╗ ██████╗ ██████╗ ███╗   ███╗
╚══██╔══╝██╔══██╗██╔══██╗████╗  ██║██╔════╝██╔════╝██╔═══██╗██╔══██╗████╗ ████║
   ██║   ██████╔╝███████║██╔██╗ ██║███████╗█████╗  ██║   ██║██████╔╝██╔████╔██║
   ██║   ██╔══██╗██╔══██║██║╚██╗██║╚════██║██╔══╝  ██║   ██║██╔══██╗██║╚██╔╝██║
   ██║   ██║  ██║██║  ██║██║ ╚████║███████║██║     ╚██████╔╝██║  ██║██║ ╚═╝ ██║
   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝╚═╝      ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝

┌──────────────────────────────────────────────────────────────────────────────┐
│                              Region: us-east-1                               │
└──────────────────────────────────────────────────────────────────────────────┘
┌──────────────────────────────────────────────────────────────────────────────┐
│                                Trusted Tools                                 │
│                                                                              │
│ Built-in Trusted Tools                                                       │
│   Configuration: Built-in read-only tools                                    │
│   • file_read                                                                │
│   • grep                                                                     │
│   • get_transformation_from_registry                                         │
│   • list_available_transformations_from_registry                             │
│   • document_manager (add operations only)                                   │
│   • editor (view and find_line operations only)                              │
│                                                                              │
│ Use -t to trust all, or see /Users/soonbeom/.aws/atx/trust-settings.yaml     │
└──────────────────────────────────────────────────────────────────────────────┘

Welcome to AWS Transform. You can discover, create, and execute transformations (AWS-managed or custom ones published to your registry). How can I help?
>
```

```
> 넌 누구니?
>

📝 Conversation log: /Users/soonbeom/.aws/atx/custom/20260819_054850_f1eb15fe/logs/2026-08-19T05-48-51-conversation.log
📊 Monitor progress: tail -f /Users/soonbeom/.aws/atx/custom/20260819_054850_f1eb15fe/logs/2026-08-19T05-48-51-conversation.log
If interrupted, you can resume this conversation by running: atx --conversation-id 20260819_054850_f1eb15fe

ATX: 저는 AWS Transform CLI입니다. AWS Transform custom 기능을 기반으로 코드 및 인프라 변환 작업을 도와드립니다.

주요 기능으로는:

- 변환 정의(Transformation Definition) 생성, 수정, 게시
- 기존 변환 조회 및 코드베이스에 적용
- 리포지토리 스캔을 통한 변환 추천
- 변환 정의 품질 검토

코드 현대화나 마이그레이션 프로젝트에서 변환 작업이 필요하시면 도와드리겠습니다. 무엇을 도와드릴까요?


> 코드 현대화?  마이그레이션?


ATX: 네, 간단히 설명드릴게요.

AWS Transform custom은 AI 기반의 코드 변환 서비스입니다. 주로 이런 작업들을 도와드립니다:

코드 현대화 (Modernization):
- 언어 버전 업그레이드: Java 8에서 17로, Python 3.9에서 3.13으로
- 프레임워크 업그레이드: Spring Boot 2.x에서 3.x, React 17에서 18
- API 마이그레이션: AWS SDK v1에서 v2, JUnit 4에서 5

마이그레이션 (Migration):
- 프레임워크 전환: Angular에서 React, Redux에서 Zustand
- 빌드 시스템 전환: Maven에서 Gradle, Webpack에서 Vite
- 아키텍처 전환: x86에서 AWS Graviton, 온프레미스에서 Lambda
- 스크립트 변환: Terraform에서 CloudFormation, Bash에서 PowerShell

작동 방식은 이렇습니다:
1. 자연어로 변환 규칙을 정의하고
2. 코드베이스에 자동으로 적용하며
3. 빌드/테스트로 검증하고
4. 실행할 때마다 학습하여 품질이 개선됩니다

새로운 변환을 만들거나, 기존 변환을 적용하거나, 리포지토리를 스캔해서 적용 가능한 변환을 추천받을 수도 있습니다. 어떤 작업을 도와드릴까요?


> aws transform 과 aws transform custome 은 어떤 차이야?


ATX: 좋은 질문이에요. 간단히 정리하면 이렇습니다.

AWS Transform은 전체 포트폴리오(umbrella)이고, AWS Transform custom은 그 안에 포함된 하나의 서비스입니다.

---

AWS Transform (전체 포트폴리오):

여러 전문화된 서비스를 포함합니다:
- Mainframe: COBOL, PL/I, JCL 등 메인프레임 현대화 전문
- Windows: .NET Framework에서 .NET Core, SQL Server 마이그레이션 전문
- VMware: VMware에서 AWS로의 인프라 마이그레이션 전문
- Assessments: 인프라 평가, 현대화 계획 수립
- Custom: 범용 코드 변환 (지금 사용 중인 서비스)

AWS Transform web application에서 이 모든 서비스에 접근할 수 있습니다.

---

AWS Transform custom (이 서비스):

범용 코드 변환 서비스로, 특정 플랫폼에 국한되지 않습니다:
- 자연어로 변환 규칙을 정의
- 언어 업그레이드, 프레임워크 전환, API 마이그레이션 등 다양한 패턴 지원
- AWS에서 사전 제작한 변환(AWS-managed transformations)도 제공
- 사용자가 직접 커스텀 변환을 만들 수도 있음
- CLI(atx)와 웹 앱 모두에서 사용 가능

---

요약하면, 메인프레임/Windows/VMware 같은 특화된 마이그레이션은 각 전문 서비스를 사용하고, 그 외 일반적인 코드 변환 작업은 AWS Transform custom으로 처리하는 구조입니다.

더 궁금한 점 있으시면 말씀해주세요!
```

### 3. definition 리스트 조회 ### 

```
> atx custom def list
```

[결과]
```
🔧  Using tool: list_available_transformations_from_registry (trusted)
 ⋮
 ● No parameters
 ⋮
Found 33 transformation definitions
  - 33 AWS Managed transformations

🏢 AWS Managed Transformations:

┌─────┬───────────────────────────────────┬────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┬────────────┐
│ #   │ Transformation Name               │ Description                                                                                                        │ Version    │
├─────┼───────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────┤
│ 1   │ 🏢 AWS/java-aws-sdk-v1-to-v2      │ Upgrade the AWS SDK from V1 to V2 for Java projects using Maven or Gradle.                                         │ 2026-07-31 │
│     │                                   │                                                                                                                    │            │
├─────┼───────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────┤
│ 2   │ 🏢 AWS/nodejs-aws-sdk-v2-to-      │ Upgrade Node.js applications from AWS SDK for JavaScript v2 to v3 to leverage modular architecture, first-class Ty │ 2025-10-16 │
│     │ v3                                │ peScript support, middleware stack, and improved performance while ensuring all AWS service interactions continue  │            │
│     │                                   │ to function correctly, without modifying the underlying Node.js version.                                           │            │
├─────┼───────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────┤
│ 3   │ 🏢 AWS/python-boto2-to-boto3      │ Migrate Python applications from boto2 to boto3, based on the official AWS migration documentation                 │ 2025-10-16 │
│     │                                   │                                                                                                                    │            │
├─────┼───────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────┤
│ 4   │ 🏢 AWS/python-version-upgrad      │ Migrate Python projects from Python 3.8/3.9 to Python 3.11/3.12/3.13, ensuring compatibility with the latest Pytho │ 2025-10-01 │
│     │ e                                 │ n features, security updates, and runtime while maintaining functionality and performance. You can specify your de │            │
│     │                                   │ sired target Python version either through interactive chat with the agent, or by passing an additionalPlanContext │            │
│     │                                   │  configuration parameter (ex. atx custom def exec --configuration "additionalPlanContext=This is a Python app that │            │
│     │                                   │  should be upgraded to Python 3.12"). You can also pass this in a configuration file (ex. atx custom def exec --co │            │
│     │                                   │ nfiguration 'file://config.json'). For an example configuration file, run atx custom def exec -h                   │            │
├─────┼───────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────┤
│ 5   │ 🏢 AWS/nodejs-version-upgrad      │ Upgrade NodeJS applications from any source NodeJS version to any target NodeJS version. You can specify your desi │ 2026-02-20 │
│     │ e                                 │ red target NodeJS version either through interactive chat with the agent, or by passing an additionalPlanContext c │            │
│     │                                   │ onfiguration parameter (ex. atx custom def exec --configuration "additionalPlanContext=This is a Node.js app that  │            │
│     │                                   │ should be upgraded to Node.js 22"). You can also pass this in a configuration file (ex. atx custom def exec --conf │            │
│     │                                   │ iguration 'file://config.json'). For an example configuration file, run atx custom def exec -h                     │            │
├─────┼───────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────┤
│ 6   │ 🏢 AWS/java-version-upgrade       │ Upgrade Java applications using any build system from any source JDK version to any target JDK version with compre │ 2025-11-11 │
│     │                                   │ hensive dependency modernization including Jakarta EE migration, database drivers, ORM frameworks, and Spring ecos │            │
│     │                                   │ ystem updates. You can specify your desired target JDK version either through interactive chat with the agent, or  │            │
│     │                                   │ by passing an additionalPlanContext configuration parameter (ex. atx custom def exec --configuration "additionalPl │            │
│     │                                   │ anContext=This is a Maven app that should be upgraded to Java 21"). You can also pass this in a configuration file │            │
│     │                                   │  (ex. atx custom def exec --configuration 'file://config.json'). For an example configuration file, run atx custom │            │
│     │                                   │  def exec -h                                                                                                       │            │
├─────┼───────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────┤
│ 7   │ 🏢 AWS/early-access-java-x86      │ Validates Java application compatibility with Arm64 architecture for running on AWS Graviton Processors. Identifie │ 2026-02-06 │
│     │ -to-graviton                      │ s and resolves Arm64 incompatibilities by updating dependencies, detecting architecture-specific code patterns, an │            │
│     │                                   │ d recompiling native libraries when source code is available. Makes targeted code modifications necessary for Arm6 │            │
│     │                                   │ 4 support (architecture detection, native library loading, etc.) but does not perform general code refactoring. Ma │            │
│     │                                   │ intains current Java version and JDK distribution and validates compatibility through build and test execution. Fo │            │
│     │                                   │ r optimal results, run in an Arm64-based environment. Note: Many modern Java applications are already Arm64-compat │            │
│     │                                   │ ible.                                                                                                              │            │
├─────┼───────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────┤
│ 8   │ 🏢 AWS/early-access-angular-      │ Transform an Angular application to React with comprehensive validation, including Playwright E2E domain-model tes │ 2026-07-09 │
│     │ to-react-migration                │ ts and a migration report containing visual regression screenshots and business logic coverage.                    │            │
├─────┼───────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────┤
│ 9   │ 🏢 AWS/comprehensive-codebas      │ This transformation performs deep static analysis of codebases to generate hierarchical, cross-referenced document │ 2026-04-14 │
│     │ e-analysis                        │ ation covering all aspects of the system. It combines behavioral analysis, architectural documentation, and busine │            │
│     │                                   │ ss intelligence extraction to create a comprehensive knowledge base organized for maximum usability and navigation │            │
│     │                                   │ . The transformation places special emphasis on technical debt analysis, providing prominent, actionable insights  │            │
│     │                                   │ on outdated components and maintenance concerns at the root level.                                                 │            │
├─────┼───────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────┤
│ 10  │ 🏢 AWS/java-performance-opti      │ Optimize Java application performance by analyzing JFR profiling data to detect CPU/memory hotspots and anti-patte │ 2026-03-31 │
│     │ mization                          │ rns, then applying targeted code fixes to reduce resource usage and improve efficiency. Instructions on collecting │            │
│     │                                   │  JFR data can be found here - https://docs.oracle.com/javacomponents/jmc-5-4/jfr-runtime-guide/run.htm.            │            │
├─────┼───────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────┤
│ 11  │ 🏢 AWS/early-access-log4j-to      │ This transformation migrates Java applications from Log4j (1.x/2.x) to SLF4J with Logback backend. Handles source  │ 2026-03-31 │
│     │ -slf4j-migration                  │ code, dependency management (Maven/Gradle), and logging configuration files. Validates via compile, test, and resi │            │
│     │                                   │ dual import scan.                                                                                                  │            │
├─────┼───────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────┤
│ 12  │ 🏢 AWS/angular-version-upgra      │ This is an early-access transformation to transform an older Angular application to a target Angular version by up │ 2026-03-31 │
│     │ de                                │ grading components, services, templates, and routing to modern Angular patterns.                                   │            │
├─────┼───────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────┤
│ 13  │ 🏢 AWS/vue.js-version-upgrad      │ An early-access transformation for major version upgrades from Vue.js 2 to Vue.js 3 to modernize components, state │ 2026-03-31 │
│     │ e                                 │  management, routing, and global APIs to Vue.js 3 patterns. Minor or patch updates are outside the scope.          │            │
├─────┼───────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────┤
│ 14  │ 🏢 AWS/agentic-readiness-ana      │ This is an early-access transformation that evaluates whether systems are ready to be safely called by AI agents - │ 2026-05-14 │
│     │ lysis                             │  covering APIs, identity, state management, human-in-the-loop, and observability.                                  │            │
├─────┼───────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────┤
│ 15  │ 🏢 AWS/modernization-readine      │ This is an early-access transformation that scans portfolios for cloud-native maturity gaps and maps findings to A │ 2026-05-14 │
│     │ ss-analysis                       │ WS modernization pathways.                                                                                         │            │
├─────┼───────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────┤
│ 16  │ 🏢 AWS/oracle-java-to-corret      │ This is an early-access transformation that migrates Java projects from Oracle JDK to Amazon Corretto. Replaces Or │ 2026-05-14 │
│     │ to                                │ acle-specific internal APIs (sun.*, com.sun.*, com.oracle.*) with standard Java equivalents, updates build configu │            │
│     │                                   │ rations (Maven/Gradle), replaces container base images (Oracle, eclipse-temurin, openjdk, adoptopenjdk) with amazo │            │
│     │                                   │ ncorretto, updates CI workflow distribution fields, removes commercial JVM flags, fixes annotation-processor JDK i │            │
│     │                                   │ ncompatibilities (Lombok), handles Alpine-to-Amazon-Linux package translation, and generates a LICENSING_REPORT.md │            │
│     │                                   │  with cost savings. Triggers: Oracle JDK migration, Corretto migration, Java vendor switch, JDK licensing, sun.mis │            │
│     │                                   │ c replacement, Alpine Docker migration, Gradle multi-module.                                                       │            │
├─────┼───────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────┤
│ 17  │ 🏢 AWS/oracle-service-bus-to      │ This is an early-access transformation that migrates Oracle Service Bus (OSB) and BPEL process configurations to A │ 2026-05-14 │
│     │ -aws                              │ WS-native serverless architecture by generating a deployable CDK TypeScript project with API Gateway, Lambda, and  │            │
│     │                                   │ Step Functions from OSB proxy/pipeline/business service XML definitions.                                           │            │
├─────┼───────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────┤
│ 18  │ 🏢 AWS/JBoss-to-Spring-Boot       │ This is an early-access transformation that migrates Java EE/Jakarta EE enterprise applications running on JBoss E │ 2026-06-18 │
│     │                                   │ AP or WildFly application servers to Spring Boot, eliminating application server dependencies, modernizing to a cl │            │
│     │                                   │ oud-native containerized deployment model, and improving developer productivity, deployment velocity, and resource │            │
│     │                                   │  efficiency.                                                                                                       │            │
├─────┼───────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────┤
│ 19  │ 🏢 AWS/datadog-monitors-to-c      │ This is an early-access transformation that migrates DataDog Metric Monitors (metric alert, query alert) tracking  │ 2026-05-14 │
│     │ loudwatch-alarms                  │ AWS service metrics (aws.* prefix) and custom metrics (Metric Streams or IAM Role polling integration) to native C │            │
│     │                                   │ loudWatch Alarms as infrastructure-as-code. Classifies monitors into Standard, Metrics Insights (MI), or Metric Ma │            │
│     │                                   │ th alarms. Generates CloudFormation YAML, CDK TypeScript, and/or Terraform HCL. Supports JSON exports, Terraform c │            │
│     │                                   │ onfig (.tf), state (.tfstate), and plan (.tfplan) inputs. Handles ANOMALY_DETECTION_BAND, arithmetic expressions,  │            │
│     │                                   │ MI SQL fleet monitoring, and .as_count() simplification. Detects DataDog integration type (Metric Streams vs IAM R │            │
│     │                                   │ ole polling) and resolves custom metric names via CloudWatch list-metrics inventory. Triggers: DataDog migration,  │            │
│     │                                   │ CloudWatch alarms, monitor conversion, AWS monitoring.                                                             │            │
├─────┼───────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────┤
│ 20  │ 🏢 AWS/spring-boot-version-u      │ Migrate Spring Boot 3.x projects to Spring Boot 4.x (targeting 4.1.0 GA). Covers version upgrades, starter renames │ 2026-06-25 │
│     │ pgrade                            │ , Jackson 3 migration, Spring Security 7 DSL, @MockBean removal, property renames, package relocations, observabil │            │
│     │                                   │ ity consolidation, Spring AI 2.0, Spring Cloud 2025.1, Spring Batch, Kafka, AMQP, gRPC, Native/AOT, Jersey, JSpeci │            │
│     │                                   │ fy, embedded server changes, third-party compatibility, and verification.                                          │            │
├─────┼───────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────┤
│ 21  │ 🏢 AWS/portfolio-modernizati      │ This is an early-access transformation that aggregates individual Modernization Analysis reports across a portfoli │ 2026-05-18 │
│     │ on-readiness-analysis             │ o of applications, producing a consolidated modernization roadmap with prioritized migration waves, recommended mo │            │
│     │                                   │ dernization pathways, and AWS program recommendations including workshops and enablement resources tailored to eac │            │
│     │                                   │ h portfolio's modernization needs.                                                                                 │            │
├─────┼───────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────┤
│ 22  │ 🏢 AWS/portfolio-agentic-rea      │ This is an early-access transformation that aggregates individual Agentic Readiness Analysis reports across a port │ 2026-05-18 │
│     │ diness-analysis                   │ folio of applications, identifying cross-cutting blockers, shared remediation patterns, and organizational readine │            │
│     │                                   │ ss gaps. Produces prioritized recommendations mapped to AWS programs, workshops, and enablement resources tailored │            │
│     │                                   │  to each portfolio's agentic adoption journey.                                                                     │            │
├─────┼───────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────┤
│ 23  │ 🏢 AWS/GenAI-to-Bedrock-Migr      │ This early-access transformation assesses generative AI workloads for migration from third-party providers (OpenAI │ 2026-06-05 │
│     │ ation-Assessment                  │ , Google Gemini, Anthropic direct, and open-source models) to AWS Bedrock by running a five-phase process - discov │            │
│     │                                   │ ering AI SDK usage and models from application code or billing exports, clarifying migration requirements, designi │            │
│     │                                   │ ng a compatibility-guided Bedrock model mapping, estimating cost and risk, and generating assessment artifacts (SD │            │
│     │                                   │ K migration guide, cost estimates, setup scripts, and run books). It is assessment-only and does not modify custom │            │
│     │                                   │ er source code; it also covers agentic frameworks (CrewAI, LangGraph, Strands/AgentCore) through retarget, harness │            │
│     │                                   │ , or Strands migration approaches.                                                                                 │            │
├─────┼───────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────┤
│ 24  │ 🏢 AWS/vba-to-python-migrati      │ This early-access transformation migrates Excel VBA macros, modules, UserForms, and embedded logic to equivalent P │ 2026-06-05 │
│     │ on                                │ ython scripts and modules. Replaces Excel-dependent automation with portable, testable Python using openpyxl, pand │            │
│     │                                   │ as, tkinter/PyQt6, and standard libraries. Source language: VBA. Target language: Python 3.8+. Use when converting │            │
│     │                                   │  .bas, .cls, .frm, or .xlsm-embedded VBA code to Python.                                                           │            │
├─────┼───────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────┤
│ 25  │ 🏢 AWS/ruby-upgrade               │ An early-access transformation that upgrades Ruby applications from Ruby 2.x to Ruby 4.0, and their frameworks to  │ 2026-06-22 │
│     │                                   │ Rails 8.0 or Sinatra 4.1. Supports Rails/ActiveRecord apps, Sinatra apps, and standalone gems. Pairs each Ruby ver │            │
│     │                                   │ sion bump with the matching framework upgrade, runs the test suite, and isolates failures before advancing. Active │            │
│     │                                   │ Record only; Mongoid/MongoDB ODM not supported.                                                                    │            │
├─────┼───────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────┤
│ 26  │ 🏢 AWS/lambda-nodejs-runtime      │ This early-access transformation upgrades AWS Lambda functions from older Node.js runtimes (nodejs4.3 through node │ 2026-06-05 │
│     │ -upgrade                          │ js22.x) to nodejs24.x, addressing all breaking changes in the Lambda Runtime Interface Client (RIC) and Node.js 24 │            │
│     │                                   │  language runtime.                                                                                                 │            │
├─────┼───────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────┤
│ 27  │ 🏢 AWS/security-issue-fixer       │ This transformation fixes security vulnerabilities in source code based on third-party scanner results (SARIF, JSO │ 2026-08-06 │
│     │                                   │ N, CSV, or plain-text findings with CWE IDs, file paths, and line numbers). It does not perform scanning or discov │            │
│     │                                   │ ery; it only remediates supplied findings while preserving functional behavior. Covers injection (CWE-78/79/89/90/ │            │
│     │                                   │ 94/943), broken authentication (CWE-287/306/798), cryptographic failures (CWE-327/328/208), IDOR/authorization (CW │            │
│     │                                   │ E-639/862/863), CSRF (CWE-352), insecure deserialization (CWE-502), SSRF (CWE-918), path traversal (CWE-22), open  │            │
│     │                                   │ redirect (CWE-601), XXE (CWE-611), JWT bypass (CWE-347), mass assignment (CWE-915), file upload (CWE-434), clearte │            │
│     │                                   │ xt transmission (CWE-319), dangerous functions (CWE-242/676/479/489), error handling (CWE-703/252), file permissio │            │
│     │                                   │ ns (CWE-732/377/829), and secrets exposure. Handles dependency changes with BOM awareness, native-image build vali │            │
│     │                                   │ dation, and multi-stage CI discovery. Supports Python, JavaScript/TypeScript, Java, Go, C#/.NET, C/C++ and Ruby.   │            │
├─────┼───────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────┤
│ 28  │ 🏢 AWS/mulesoft-to-aws-nativ      │ Transforms MuleSoft Mule 3.x/4.x applications into AWS serverless architectures (API Gateway + Lambda + Step Funct │ 2026-06-25 │
│     │ e-java                            │ ions) targeting Java 17 on Lambda with SnapStart. Maps flow triggers to AWS event sources, converts DataWeave/MEL  │            │
│     │                                   │ to tiered AWS equivalents (VTL, Step Functions, Lambda), replaces connectors with AWS SDK for Java v2 calls, and o │            │
│     │                                   │ rchestrates flows with Step Functions. Produces SAM templates, Java Lambda handler code, Maven pom.xml, architectu │            │
│     │                                   │ re docs, and JUnit 5 tests.                                                                                        │            │
├─────┼───────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────┤
│ 29  │ 🏢 AWS/business-rules-extrac      │ An early-access transformation that statically analyzes a monolithic codebase to produce rewrite-ready documentati │ 2026-06-22 │
│     │ tion                              │ on - without building, running, or modifying source. Decomposes the system into bounded domains and extracts per-d │            │
│     │                                   │ omain business rules, workflows, cross-cutting concerns, and database structure into a machine-readable manifest a │            │
│     │                                   │ nd interactive dashboard. Then generates a self-contained, language-neutral implementation specification for each  │            │
│     │                                   │ domain to guide modernization or rewrite. Language-agnostic.                                                       │            │
├─────┼───────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────┤
│ 30  │ 🏢 AWS/payshield-hsm-to-aws-      │ Migrates Java applications from Thales PayShield HSM socket-based command protocol to AWS Payment Cryptography Ser │ 2026-07-29 │
│     │ payment-cryptography              │ vice (APC) SDK v2. Covers command mapping (M2, CA, DA, KW, CW, CY, etc.), key migration (TR-31/TR-34 import, KCV v │            │
│     │                                   │ erification), SDK dependency setup (Maven/Gradle/Ant), infrastructure removal (socket pools, response parsers), te │            │
│     │                                   │ st infrastructure update, and parity testing. Triggers: PayShield, HSM migration, AWS Payment Cryptography, APC, D │            │
│     │                                   │ UKPT, TranslatePinData, DecryptData, VerifyPinData.                                                                │            │
├─────┼───────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────┤
│ 31  │ 🏢 AWS/dotnet-lambda-upgrade      │ Upgrades AWS Lambda .NET functions from older runtimes (.NET Core 3.1, .NET 6, .NET 8) to .NET 10. Covers project  │ 2026-07-09 │
│     │                                   │ files (.csproj/.fsproj), NuGet packages (Amazon.Lambda.*, AWSSDK.*, Microsoft.Extensions.*), Lambda configuration  │            │
│     │                                   │ (SAM, Serverless Framework, CDK, Terraform, CloudFormation), Dockerfiles, code modernization, test projects, and a │            │
│     │                                   │ rtifact paths. Handles managed runtime (dotnet10), Native AOT (provided.al2023), and container-image deployment mo │            │
│     │                                   │ dels. Trigger keywords: Lambda .NET upgrade, net10.0, TFM migration, dotnet10, Amazon.Lambda, AWSSDK, csproj, fspr │            │
│     │                                   │ oj, TargetFramework.                                                                                               │            │
├─────┼───────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────┤
│ 32  │ 🏢 AWS/websphere-jaxrs-to-be      │ Generates Amazon Bedrock AgentCore tool definitions from the REST endpoints in a WebSphere or Liberty application, │ 2026-07-22 │
│     │ drock-agentcore                   │  so existing business logic can be called by AI agents. Your application stays where it is: the transformation rea │            │
│     │                                   │ ds your source code and writes new files to an output directory without changing anything in place. It finds endpo │            │
│     │                                   │ ints that use the Java API for RESTful Web Services (JAX-RS) in both the javax.ws.rs and jakarta.ws.rs namespaces, │            │
│     │                                   │  including Enterprise JavaBeans (EJB) exposed through a JAX-RS facade. For each endpoint it maps Java parameters a │            │
│     │                                   │ nd types to a JSON schema, resolves the HTTP method, and rates its confidence so you know what to review. The outp │            │
│     │                                   │ ut is a discovery report, a JSON schema per endpoint, tool implementations in Python, and a manifest for registeri │            │
│     │                                   │ ng them with an AgentCore gateway. Generated code is checked for valid syntax. Java tool output is planned for a l │            │
│     │                                   │ ater release. Triggers: WebSphere, Liberty, JAX-RS, EJB, AgentCore, Bedrock.                                       │            │
├─────┼───────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────┤
│ 33  │ 🏢 AWS/mulesoft-to-aws-nativ      │ Transforms MuleSoft Mule 3.x/4.x applications into AWS serverless architectures (API Gateway + Lambda + Step Funct │ 2026-08-04 │
│     │ e-python                          │ ions) targeting Python 3.12 on Lambda. Maps flow triggers to AWS event sources, converts DataWeave/MEL to tiered A │            │
│     │                                   │ WS equivalents (VTL, Step Functions, Lambda), replaces connectors with boto3 AWS SDK calls, and orchestrates flows │            │
│     │                                   │  with Step Functions. Produces SAM templates, Python Lambda handler code, pinned requirements.txt with a dependenc │            │
│     │                                   │ y lockfile, architecture docs, a deployment runbook with samconfig.toml, and pytest tests. Triggers: MuleSoft migr │            │
│     │                                   │ ation, Mule to AWS, DataWeave conversion, connector replacement, SAM template generation, Lambda Powertools Python │            │
│     │                                   │ , pytest, serverless migration.                                                                                    │            │
└─────┴───────────────────────────────────┴────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┴────────────┘

 ● Completed in 2.1s

ATX: 총 33개의 변환이 발견되었습니다 (AWS Managed 33개, 사용자 변환 0개).

| # | 이름 | 설명 |
|---|------|------|
| 1 | AWS/java-aws-sdk-v1-to-v2 | Java AWS SDK V1에서 V2로 업그레이드 (Maven/Gradle) |
| 2 | AWS/nodejs-aws-sdk-v2-to-v3 | Node.js AWS SDK v2에서 v3로 업그레이드 |
| 3 | AWS/python-boto2-to-boto3 | Python boto2에서 boto3로 마이그레이션 |
| 4 | AWS/python-version-upgrade | Python 3.8/3.9에서 3.11/3.12/3.13으로 업그레이드 |
| 5 | AWS/nodejs-version-upgrade | Node.js 버전 업그레이드 |
| 6 | AWS/java-version-upgrade | Java 버전 업그레이드 (모든 빌드 시스템) |
| 7 | AWS/early-access-java-x86-to-graviton | Java x86에서 AWS Graviton(Arm64) 호환성 검증 |
| 8 | AWS/early-access-angular-to-react-migration | Angular에서 React로 전환 |
| 9 | AWS/comprehensive-codebase-analysis | 코드베이스 종합 분석 및 문서화 |
| 10 | AWS/java-performance-optimization | JFR 프로파일링 기반 Java 성능 최적화 |
| 11 | AWS/early-access-log4j-to-slf4j-migration | Log4j에서 SLF4J/Logback으로 마이그레이션 |
| 12 | AWS/angular-version-upgrade | Angular 버전 업그레이드 |
| 13 | AWS/vue.js-version-upgrade | Vue.js 2에서 3으로 업그레이드 |
| 14 | AWS/agentic-readiness-analysis | AI 에이전트 준비 상태 평가 |
| 15 | AWS/modernization-readiness-analysis | 현대화 준비 상태 분석 |
| 16 | AWS/oracle-java-to-corretto | Oracle JDK에서 Amazon Corretto로 전환 |
| 17 | AWS/oracle-service-bus-to-aws | Oracle Service Bus에서 AWS 서버리스로 전환 |
| 18 | AWS/JBoss-to-Spring-Boot | JBoss/WildFly에서 Spring Boot로 전환 |
| 19 | AWS/datadog-monitors-to-cloudwatch-alarms | DataDog 모니터에서 CloudWatch 알람으로 전환 |
| 20 | AWS/spring-boot-version-upgrade | Spring Boot 3.x에서 4.x로 업그레이드 |
| 21 | AWS/portfolio-modernization-readiness-analysis | 포트폴리오 현대화 준비 상태 종합 분석 |
| 22 | AWS/portfolio-agentic-readiness-analysis | 포트폴리오 에이전틱 준비 상태 종합 분석 |
| 23 | AWS/GenAI-to-Bedrock-Migration-Assessment | GenAI 워크로드 Bedrock 마이그레이션 평가 |
| 24 | AWS/vba-to-python-migration | Excel VBA에서 Python으로 전환 |
| 25 | AWS/ruby-upgrade | Ruby 2.x에서 4.0/Rails 8.0으로 업그레이드 |
| 26 | AWS/lambda-nodejs-runtime-upgrade | Lambda Node.js 런타임 nodejs24.x로 업그레이드 |
| 27 | AWS/security-issue-fixer | 보안 취약점 수정 (SARIF/JSON/CSV 스캐너 결과 기반) |
| 28 | AWS/mulesoft-to-aws-native-java | MuleSoft에서 AWS 서버리스(Java)로 전환 |
| 29 | AWS/business-rules-extraction | 비즈니스 규칙 추출 및 도메인 분해 |
| 30 | AWS/payshield-hsm-to-aws-payment-cryptography | PayShield HSM에서 AWS Payment Cryptography로 전환 |
| 31 | AWS/dotnet-lambda-upgrade | .NET Lambda 함수 .NET 10으로 업그레이드 |
| 32 | AWS/websphere-jaxrs-to-bedrock-agentcore | WebSphere JAX-RS에서 Bedrock AgentCore 도구 생성 |
| 33 | AWS/mulesoft-to-aws-native-python | MuleSoft에서 AWS 서버리스(Python)로 전환 |

번호나 이름을 입력하면 해당 변환을 조회, 수정, 또는 적용할 수 있습니다. 리포지토리를 스캔해서 적합한 변환을 추천받을 수도 있습니다
```


### 4. custom 변환 ###
```
> 그라비톤 전톤 전환 관련해서는 자바만 지원하는 구나?


ATX: 네, 현재 AWS Managed 변환 중에서 Graviton(Arm64) 전환은 Java만 지원합니다 (7번: AWS/early-access-java-x86-to-graviton).

이 변환은 Java 애플리케이션의 Arm64 호환성을 검증하고, 아키텍처별 의존성 업데이트, 네이티브 라이브러리 재컴파일, 아키텍처 감지 코드 수정 등을 처리합니다.

다른 언어(Python, Node.js, Go 등)의 Graviton 전환이 필요하시다면, 커스텀 변환을 직접 만들어서 사용할 수 있습니다. 다만 참고로, Python이나 Node.js 같은 인터프리터 언어는 대부분 별도 코드 수정 없이 Graviton에서 바로 동작하는 경우가 많고, 주로 네이티브 바이너리 의존성이 있는 경우에만 작업이 필요합니다.

Graviton 전환을 적용하시겠어요, 아니면 다른 언어용 커스텀 변환을 만들어볼까요?


> 어떻게 직접 만들지?


ATX: 커스텀 변환을 만드는 과정은 이렇습니다:

1. 어떤 변환을 원하는지 자연어로 설명해주시면 됩니다 (예: "Python 앱을 x86에서 Graviton으로 전환")
2. 제가 몇 가지 질문을 드려서 요구사항을 정리합니다
3. 그 내용을 바탕으로 변환 정의를 자동으로 생성합니다
4. 테스트 후 게시하면 반복적으로 사용할 수 있습니다

코드베이스 경로를 알려주시면 실제 코드를 먼저 분석해서 더 정확한 변환을 만들 수도 있고요.

지금 바로 만들어볼까요? 어떤 종류의 변환이 필요하신지 말씀해주세요.


> node.js 앱을 그라비톤에 적용하고 싶은데, 소스 코드는 없어.


ATX: Node.js 앱의 Graviton(Arm64) 전환은 주로 네이티브 바이너리 의존성(node-gyp, C++ addons 등)이 핵심 포인트입니다. 인터프리터 코드 자체는 대부분 문제없지만, 네이티브 모듈이나 Docker 이미지, CI/CD 설정 등에서 아키텍처별 처리가 필요하죠.

소스 코드가 없으니 범용적으로 만들겠습니다. 몇 가지 질문 드릴게요:

1. 대상 Node.js 버전은 어떤 범위인가요?
   - 추천: Node.js 16 이상 (16, 18, 20, 22)

2. 배포 환경은 어떤 형태인가요? (Docker 컨테이너, EC2, Lambda, ECS 등)
   - 추천: Docker 컨테이너 기반 (가장 일반적인 Graviton 전환 시나리오)

3. 네이티브 모듈 처리 범위는 어디까지 원하시나요?
   - 추천: package.json 내 네이티브 의존성 식별, Arm64 호환 대안 제시, node-gyp 빌드 설정 수정 포함

"use defaults"를 입력하시면 추천 답변을 수락하고 추가 질문을 계속하며, "done"을 입력하시면 바로 변환 생성을 시작합니다.

```

### 5. AWS/early-access-java-x86-to-graviton 변환 ###
```
> AWS/early-access-java-x86-to-graviton


ATX: AWS/early-access-java-x86-to-graviton은 AWS Managed 변환입니다.

설명: Java 애플리케이션의 Arm64(AWS Graviton) 호환성을 검증합니다. Arm64 비호환 의존성 업데이트, 아키텍처별 코드 패턴 감지, 네이티브 라이브러리 재컴파일 등을 처리합니다. 최적의 결과를 위해 Arm64 환경에서 실행하는 것을 권장합니다.

AWS Managed 변환은 내용을 조회하거나 수정할 수 없고, 코드에 적용만 가능합니다.

이 변환을 코드베이스에 적용하시겠어요? 적용하시려면 대상 리포지토리 경로를 알려주세요.

아니면, 아까 진행하던 Node.js Graviton 커스텀 변환 생성을 계속할까요?


> 네이티브 라이브러리 컴파일도 니가 할수 있다고?


ATX: 변환이 직접 하는 것은 아닙니다. 좀 더 정확히 말하면:

- 네이티브 라이브러리의 소스 코드가 프로젝트에 포함되어 있는 경우, Arm64용으로 빌드 설정을 수정해줍니다 (CMakeLists.txt, Makefile 등의 아키텍처 타겟 변경)
- 사전 빌드된 바이너리(.so, .dll)만 있는 경우에는 직접 컴파일할 수 없고, Arm64 호환 버전으로 교체하거나 대안을 제시합니다

즉 "재컴파일"이라기보다는 "재컴파일이 가능하도록 빌드 설정을 수정"하는 것에 가깝습니다. 실제 컴파일은 빌드 커맨드 실행 시 이루어지고요.

다시 돌아가서, Node.js Graviton 커스텀 변환 생성을 계속하시겠어요? 아까 드린 질문들에 답변해주시면 됩니다.


> AWS Managed 변환은 내용을 조회하거나 수정할 수 없고, 코드에 적용만 가능합니다 이게 무슨 말이ㅑㅇ?


ATX: 말 그대로, AWS Managed 변환(AWS/ 접두사가 붙은 것들)은 AWS에서 만들고 관리하는 변환입니다.

- 조회 불가: 변환 정의(내부 로직, 규칙, 단계 등)의 상세 내용을 볼 수 없습니다
- 수정 불가: AWS가 소유하고 있어서 사용자가 편집할 수 없습니다
- 적용만 가능: 코드베이스에 실행해서 결과를 받는 것만 가능합니다

비유하자면, AWS에서 제공하는 완성된 도구를 그대로 쓸 수 있지만, 도구 내부를 뜯어보거나 고칠 수는 없는 거예요.

대신 커스터마이징이 필요하면 두 가지 방법이 있습니다:

1. additionalPlanContext 파라미터로 실행 시 추가 지시를 줄 수 있습니다 (예: "타겟 Java 버전은 21로 해줘")
2. 아예 커스텀 변환을 직접 만들어서 원하는 대로 정의할 수 있습니다

더 궁금한 점 있으시면 말씀해주세요. 아니면 Node.js Graviton 변환 생성을 이어갈까요?
```

### 6. claude code ###

```
> 너를 clausde code 에 에서도 실행할 수 있어?


ATX: 아니요, AWS Transform CLI(atx)는 Claude Code와는 별개의 독립적인 도구입니다. 터미널에서 직접 실행하는 CLI이고, Claude Code 안에서 동작하는 것이 아닙니다.

AWS Transform CLI를 사용하려면:

- 터미널에서 atx 명령어로 실행
- AWS 계정과 적절한 IAM 권한 필요
- Linux, macOS, WSL 환경 지원 (Windows 네이티브는 미지원)
- Node.js 20 이상, Git 필요

설치 및 시작 방법은 공식 문서를 참고해주세요: https://docs.aws.amazon.com/transform/latest/userguide/custom-get-started.html

다른 궁금한 점 있으시면 말씀해주세요. 아니면 Node.js Graviton 변환 생성을 계속할까요?


> claude skill 관련해서 뭔가  뭔가 제공되는 것 같던데.


ATX: 아, 클라이언트 사이드 스킬(Client-Side Skills)에 대해 물어보시는 것 같네요.

AWS Transform CLI는 스킬 디렉토리 구조를 지원하는데, 일부 경로는 "cross-client" 용도로 설계되어 있습니다:

프로젝트 레벨:
- `<project>/.aws/atx/skills/` — CLI 전용
- `<project>/.agents/skills/` — 크로스 클라이언트 (호환되는 다른 에이전트 도구에서도 사용 가능)

사용자 레벨:
- `~/.aws/atx/skills/` — CLI 전용
- `~/.agents/skills/` — 크로스 클라이언트 (호환되는 다른 에이전트 도구에서도 사용 가능)

`.agents/skills/` 경로에 놓인 스킬은 AWS Transform CLI뿐 아니라 이 디렉토리 규약을 지원하는 다른 호환 에이전트 도구에서도 인식할 수 있도록 설계된 것입니다. Claude Code가 이 규약을 지원하는지는 Claude Code 쪽 문서를 확인해보시는 게 좋겠습니다.

스킬 구조는 이렇게 생겼습니다:

```
my-skill/
├── SKILL.md          # 필수: YAML frontmatter + 지시사항
├── references/       # 선택: 참조 문서
└── scripts/          # 선택: 실행 가능한 스크립트
```

더 자세한 내용이 필요하시면 말씀해주세요!


> 잘 이해가 안되는데, 그냥.  스킬 파일만 만들어 ㄷ둔다는 거지?


ATX: 네, 맞아요. 간단하게 말하면:

정해진 디렉토리에 스킬 폴더를 만들어두면, 변환 실행 시 에이전트가 자동으로 인식해서 추가 기능으로 활용합니다.

예를 들어, 프로젝트에 커스텀 검증 스킬을 추가하고 싶으면:

```
my-project/.agents/skills/my-validation/
├── SKILL.md
```

SKILL.md 안에는:

```
---
name: my-validation
description: 빌드 후 커스텀 검증 규칙 적용
---

# 검증 규칙

1. 모든 API 응답에 에러 핸들링이 있는지 확인
2. 로깅이 표준 포맷을 따르는지 확인
...
```

이게 전부예요. 별도 설치나 등록 없이, 폴더에 넣어두기만 하면 됩니다.

변환을 실행할 때 에이전트가 해당 디렉토리를 스캔하고, 스킬을 발견하면 자동으로 로드해서 사용합니다. 스킬이 유효하지 않으면 건너뛰고 로그에 경고만 남기고요.

Node.js Graviton 변환 생성을 이어갈까요, 아니면 다른 궁금한 점 있으신가요?


> 다시 확인 할께. 결국  스킬 파일만 만들어 ㄷ주는 것이고, 변환 자체는 해당  에이전트 툴이 해 주는 거다?


ATX: 네, 정확합니다.

- 스킬 파일: 에이전트에게 "이렇게 해라"라는 지시사항을 제공하는 것
- 변환 실행: 에이전트가 그 지시사항을 읽고 실제 코드 변환을 수행하는 것

스킬은 설명서이고, 에이전트가 실행자입니다.

`.agents/skills/` 경로에 넣어두면 그 규약을 지원하는 호환 에이전트 도구가 알아서 읽고 활용하는 구조입니다.

다른 궁금한 점 있으시면 말씀해주세요!


> .agents/skills 이 구조는  공통 구조인거야?


ATX: 솔직히 말씀드리면, `.agents/skills/`는 AWS Transform CLI에서 "cross-client"로 명명한 경로입니다. 즉, AWS Transform 쪽에서 다른 에이전트 도구와도 호환될 수 있도록 의도한 규약이에요.

하지만 이게 업계 전체의 공식 표준인지, 또는 어떤 다른 에이전트 도구들이 실제로 이 경로를 지원하는지는 제가 확인해드리기 어렵습니다. 각 도구의 문서를 직접 확인해보시는 게 정확합니다.

AWS Transform CLI 기준으로 정리하면:

- `.aws/atx/skills/` — AWS Transform CLI만 인식
- `.agents/skills/` — AWS Transform CLI도 인식하고, 같은 규약을 채택한 다른 도구도 인식할 수 있도록 열어둔 경로

다른 궁금한 점 있으시면 말씀해주세요!
```

```
> 너를 clausde code 에 에서도 실행할 수 있어?


ATX: 아니요, AWS Transform CLI(atx)는 Claude Code와는 별개의 독립적인 도구입니다. 터미널에서 직접 실행하는 CLI이고, Claude Code 안에서 동작하는 것이 아닙니다.

AWS Transform CLI를 사용하려면:

- 터미널에서 atx 명령어로 실행
- AWS 계정과 적절한 IAM 권한 필요
- Linux, macOS, WSL 환경 지원 (Windows 네이티브는 미지원)
- Node.js 20 이상, Git 필요

설치 및 시작 방법은 공식 문서를 참고해주세요: https://docs.aws.amazon.com/transform/latest/userguide/custom-get-started.html

다른 궁금한 점 있으시면 말씀해주세요. 아니면 Node.js Graviton 변환 생성을 계속할까요?


> claude skill 관련해서 뭔가  뭔가 제공되는 것 같던데.


ATX: 아, 클라이언트 사이드 스킬(Client-Side Skills)에 대해 물어보시는 것 같네요.

AWS Transform CLI는 스킬 디렉토리 구조를 지원하는데, 일부 경로는 "cross-client" 용도로 설계되어 있습니다:

프로젝트 레벨:
- `<project>/.aws/atx/skills/` — CLI 전용
- `<project>/.agents/skills/` — 크로스 클라이언트 (호환되는 다른 에이전트 도구에서도 사용 가능)

사용자 레벨:
- `~/.aws/atx/skills/` — CLI 전용
- `~/.agents/skills/` — 크로스 클라이언트 (호환되는 다른 에이전트 도구에서도 사용 가능)

`.agents/skills/` 경로에 놓인 스킬은 AWS Transform CLI뿐 아니라 이 디렉토리 규약을 지원하는 다른 호환 에이전트 도구에서도 인식할 수 있도록 설계된 것입니다. Claude Code가 이 규약을 지원하는지는 Claude Code 쪽 문서를 확인해보시는 게 좋겠습니다.

스킬 구조는 이렇게 생겼습니다:

```
my-skill/
├── SKILL.md          # 필수: YAML frontmatter + 지시사항
├── references/       # 선택: 참조 문서
└── scripts/          # 선택: 실행 가능한 스크립트
```

더 자세한 내용이 필요하시면 말씀해주세요!


> 잘 이해가 안되는데, 그냥.  스킬 파일만 만들어 ㄷ둔다는 거지?


ATX: 네, 맞아요. 간단하게 말하면:

정해진 디렉토리에 스킬 폴더를 만들어두면, 변환 실행 시 에이전트가 자동으로 인식해서 추가 기능으로 활용합니다.

예를 들어, 프로젝트에 커스텀 검증 스킬을 추가하고 싶으면:

```
my-project/.agents/skills/my-validation/
├── SKILL.md
```

SKILL.md 안에는:

```
---
name: my-validation
description: 빌드 후 커스텀 검증 규칙 적용
---

# 검증 규칙

1. 모든 API 응답에 에러 핸들링이 있는지 확인
2. 로깅이 표준 포맷을 따르는지 확인
...
```

이게 전부예요. 별도 설치나 등록 없이, 폴더에 넣어두기만 하면 됩니다.

변환을 실행할 때 에이전트가 해당 디렉토리를 스캔하고, 스킬을 발견하면 자동으로 로드해서 사용합니다. 스킬이 유효하지 않으면 건너뛰고 로그에 경고만 남기고요.

Node.js Graviton 변환 생성을 이어갈까요, 아니면 다른 궁금한 점 있으신가요?


> 다시 확인 할께. 결국  스킬 파일만 만들어 ㄷ주는 것이고, 변환 자체는 해당  에이전트 툴이 해 주는 거다?


ATX: 네, 정확합니다.

- 스킬 파일: 에이전트에게 "이렇게 해라"라는 지시사항을 제공하는 것
- 변환 실행: 에이전트가 그 지시사항을 읽고 실제 코드 변환을 수행하는 것

스킬은 설명서이고, 에이전트가 실행자입니다.

`.agents/skills/` 경로에 넣어두면 그 규약을 지원하는 호환 에이전트 도구가 알아서 읽고 활용하는 구조입니다.

다른 궁금한 점 있으시면 말씀해주세요!


> .agents/skills 이 구조는  공통 구조인거야?


ATX: 솔직히 말씀드리면, `.agents/skills/`는 AWS Transform CLI에서 "cross-client"로 명명한 경로입니다. 즉, AWS Transform 쪽에서 다른 에이전트 도구와도 호환될 수 있도록 의도한 규약이에요.

하지만 이게 업계 전체의 공식 표준인지, 또는 어떤 다른 에이전트 도구들이 실제로 이 경로를 지원하는지는 제가 확인해드리기 어렵습니다. 각 도구의 문서를 직접 확인해보시는 게 정확합니다.

AWS Transform CLI 기준으로 정리하면:

- `.aws/atx/skills/` — AWS Transform CLI만 인식
- `.agents/skills/` — AWS Transform CLI도 인식하고, 같은 규약을 채택한 다른 도구도 인식할 수 있도록 열어둔 경로

다른 궁금한 점 있으시면 말씀해주세요!


> 그럼 니가 이걸 자동으로 만들어 준다?


ATX: 네, 제가 만들어드릴 수 있습니다.

제가 하는 일이 바로 변환 정의(스킬 파일)를 만들어주는 거예요. 요구사항을 정리해서 SKILL.md를 작성하고, 필요하면 참조 문서도 references/ 폴더에 넣어드립니다.

만들어진 변환은 두 가지 방식으로 사용할 수 있습니다:

1. 레지스트리에 게시 — atx CLI로 실행할 때 이름만으로 불러서 사용
2. 로컬 스킬 디렉토리에 배치 — .agents/skills/ 또는 .aws/atx/skills/에 넣어서 사용

아까 진행하던 Node.js Graviton 변환을 이어서 만들어드릴까요? 질문에 답해주시거나 "use defaults"나 "done"으로 진행하시면 됩니다.


> 아. 니가    업무 규칙을 만들고 다른 에이전트가 참조하는게 가능하다?


ATX: 네, 맞습니다. 그게 핵심이에요.

흐름을 정리하면:

1. 저(AWS Transform CLI)한테 요구사항을 말씀해주시면
2. 제가 SKILL.md(변환 규칙/지시사항)를 작성하고
3. 그 파일을 `.agents/skills/`에 넣어두면
4. 해당 규약을 지원하는 에이전트 도구가 이 스킬을 읽고 실행에 활용

즉, 저는 "규칙을 잘 정리해서 문서화하는 역할"이고, 실제 코드 변환 실행은 에이전트가 합니다. AWS Transform CLI 자체의 에이전트가 실행할 수도 있고, 같은 스킬 규약을 지원하는 다른 도구의 에이전트가 참조할 수도 있는 구조입니다.

Node.js Graviton 변환을 계속 만들어볼까요, 아니면 다른 변환을 만들어드릴까요?


> 너는 누구지?


ATX: 저는 AWS Transform CLI입니다.

하는 일을 간단히 말하면:

- 변환 정의(스킬 파일)를 만들고, 수정하고, 게시합니다
- 만들어진 변환을 코드베이스에 적용합니다
- 기존 변환을 조회하거나 추천해드립니다

코드 현대화나 마이그레이션 작업에서 "어떻게 변환할지"를 정의하고 실행하는 것을 도와드리는 도구예요.

뭘 도와드릴까요?


> Graviton in Days vs Months with AWS Transform custom, Claude Skills and Kiro Power
이 표현에서.. 그럼.. 클라드 스킬은... 니가 만든 md 팡리이다?


ATX: 네, 그렇게 이해하시면 됩니다.

그 표현에서의 구조는 이런 거예요:

- AWS Transform custom — 변환 규칙(SKILL.md)을 만들고 실행하는 서비스
- Claude Skills — `.agents/skills/`에 있는 SKILL.md 파일을 Claude가 읽고 활용하는 것
- Kiro — 마찬가지로 같은 스킬 파일을 참조할 수 있는 도구

결국 제가 만든 SKILL.md 파일이 공통 인터페이스 역할을 하는 겁니다. 한 번 만들어두면 AWS Transform CLI의 에이전트도, Claude도, Kiro도 같은 파일을 참조해서 변환 작업을 수행할 수 있는 구조죠.

"Days vs Months"라는 표현은, 이렇게 규칙을 한 번 잘 정의해두면 여러 도구에서 재사용할 수 있어서 Graviton 전환 같은 작업을 몇 달이 아니라 며칠 만에 끝낼 수 있다는 의미일 거예요.

Node.js Graviton 변환을 계속 만들어볼까요?


> 스킬 파일 만들어 봐봐 . 한번 보게.




🔧  Using tool: editor (trusted)
 ⋮
 ● Path: ~/.aws/atx/custom/20260819_054850_f1eb15fe/artifacts/tp-staging/SKILL.md
 ● Command: create
 ● File content:
---
name: nodejs-x86-to-graviton
description: Migrate Node.js applications from x86/amd64 to AWS Graviton (Arm64) architecture, addressing native modules, Docker images, and CI/CD configurations.
---

# Node.js x86 to AWS Graviton (Arm64) Migration

Migrate Node.js applications from x86/amd64 architecture to run on AWS Graviton (Arm64) processors. Focuses on identifying and resolving architecture-specific incompatibilities in native modules, container images, build configurations, and CI/CD pipelines.

## Entry Criteria

1. Project is a Node.js application (Node.js 16 or later)
2. Project contains a `package.json` file
3. Application currently targets or assumes x86/amd64 architecture
4. Git repository is initialized

## Implementation Steps

1. **Scan for architecture-specific dependencies**: Examine `package.json` and `package-lock.json` (or `yarn.lock`, `pnpm-lock.yaml`) for native modules that use node-gyp, N-API, or pre-built binaries. Common examples: `sharp`, `bcrypt`, `sqlite3`, `canvas`, `grpc`, `esbuild`, `swc`, `node-sass`.

2. **Update native module versions**: For each native dependency identified, check if the current version supports Arm64. If not, upgrade to the latest version that provides Arm64 pre-built binaries or compiles correctly on Arm64. Replace deprecated native modules with Arm64-compatible alternatives (e.g., `node-sass` to `sass`).

3. **Fix architecture-hardcoded references**: Search for hardcoded architecture strings in source code and configuration files:
   - Replace `x86_64`, `x64`, `amd64` references with architecture-agnostic alternatives
   - Use `process.arch` or `os.arch()` for runtime detection instead of hardcoded values
   - Update any platform-specific binary download URLs to include Arm64 variants

4. **Update Docker configurations**: Modify Dockerfiles for multi-architecture support:
   - Change base images to multi-arch versions (e.g., `node:20` instead of `node:20-amd64`)
   - Remove `--platform=linux/amd64` flags or change to `--platform=linux/arm64`
   - Ensure build stages use architecture-appropriate base images
   - Update any `apt-get` or `apk` packages that are architecture-specific

5. **Update CI/CD pipeline configurations**: Modify build and deployment pipelines:
   - Update runner/agent specifications to use Arm64 instances
   - Add cross-compilation steps if building on x86 for Arm64 target
   - Update artifact naming to reflect architecture
   - Ensure test stages run on Arm64 environment

6. **Update infrastructure-as-code**: Modify deployment configurations:
   - Update EC2 instance types to Graviton-based (e.g., `m6g`, `c7g`, `t4g`)
   - Update ECS task definitions with Arm64 architecture
   - Update Lambda function architectures from `x86_64` to `arm64`
   - Modify Auto Scaling Group launch templates

7. **Handle optional dependencies and fallbacks**: For modules that may not have Arm64 support:
   - Add `optionalDependencies` with architecture-specific packages
   - Configure `.npmrc` with `--arch` settings if needed
   - Add `os` and `cpu` fields to `package.json` if publishing

8. **Verify node-gyp build toolchain**: Ensure build prerequisites for Arm64 compilation are documented:
   - `python3`, `make`, `gcc`/`g++` for Arm64
   - Any library dependencies required for native compilation (e.g., `libvips-dev` for sharp)

## Validation / Exit Criteria

1. `npm install` (or `yarn install` / `pnpm install`) completes without errors on Arm64
2. All native modules compile or install pre-built Arm64 binaries successfully
3. Application starts without architecture-related errors
4. Build command passes (tests execute successfully)
5. No remaining hardcoded x86/amd64 architecture references in source or config files
6. Docker image builds successfully for linux/arm64 platform

 ● Completed in 1ms

ATX: 만들었습니다. 이런 형태예요:

```
---
name: nodejs-x86-to-graviton
description: Migrate Node.js applications from x86/amd64 to AWS Graviton (Arm64) architecture, addressing native modules, Docker images, and CI/CD configurations.
---

# Node.js x86 to AWS Graviton (Arm64) Migration
```

구조는 이렇습니다:

- YAML frontmatter (name, description) — 메타데이터
- Entry Criteria — 이 변환을 적용할 조건
- Implementation Steps — 에이전트가 따라야 할 구체적 단계들
  1. 네이티브 의존성 스캔
  2. Arm64 호환 버전으로 업데이트
  3. 하드코딩된 아키텍처 참조 수정
  4. Docker 설정 수정
  5. CI/CD 파이프라인 업데이트
  6. 인프라 코드 수정 (EC2, ECS, Lambda 등)
  7. optional dependencies 처리
  8. node-gyp 빌드 툴체인 확인
- Validation / Exit Criteria — 성공 확인 조건

이 파일을 `.agents/skills/` 에 넣어두면 호환 에이전트가 참조할 수 있고, 레지스트리에 게시하면 atx CLI로 실행할 수 있습니다.

전체 내용을 보시겠어요? 아니면:

1. 품질 리뷰 받기
2. 내용 수정하기
3. 드래프트로 저장하기
4. 레지스트리에 게시하기
5. 코드베이스에 적용하기

어떤 걸 해볼까요?


> 이런 식으로 파일 만들면  모든 코딩 에이전트가 저 규칙ㄷ대로 변환한다?


ATX: 정확히는 아닙니다. 몇 가지 조건이 있어요:

1. 에이전트가 이 스킬 파일 규약을 지원해야 합니다
   - AWS Transform CLI — 지원 (이 포맷을 만든 주체)
   - 다른 에이전트 도구 — `.agents/skills/` 규약을 채택한 경우에만 지원

2. 에이전트의 역량에 따라 결과가 달라집니다
   - 스킬 파일은 "지시사항"이지 "강제 실행 코드"가 아닙니다
   - AI 에이전트가 지시사항을 해석하고 실행하는 것이므로, 에이전트의 능력에 따라 품질이 다를 수 있어요

3. 빌드/테스트 검증이 있어야 신뢰할 수 있습니다
   - AWS Transform CLI는 빌드 커맨드를 실행해서 변환 결과를 검증합니다
   - 단순히 규칙만 따르는 게 아니라, 실제로 빌드가 통과하는지 확인하는 루프가 있어요

비유하자면, 스킬 파일은 "레시피"이고 에이전트는 "요리사"입니다. 좋은 레시피가 있어도 요리사 실력에 따라 결과가 달라지죠. 그래서 AWS Transform CLI는 "맛 검증(빌드/테스트)"까지 포함하는 겁니다.

다른 궁금한 점 있으시면 말씀해주세요!


> 근데 너를  쓰면 되지  ㄱ굳이 니가 만든 md 파일을 다른 에이전트에서 불러서 쓸일이 있어?  kiro 든 claude 든


ATX: 좋은 질문이에요. 실제로 몇 가지 시나리오가 있습니다:

1. 개발 중에 실시간으로 적용하고 싶을 때
   - AWS Transform CLI는 "변환 작업"을 일괄로 돌리는 도구
   - Kiro나 Claude Code는 개발자가 코딩하면서 같이 쓰는 도구
   - 같은 규칙을 코딩 중에도 자동으로 따르게 하고 싶다면, 스킬 파일을 프로젝트에 넣어두는 게 유용

2. 팀 컨벤션 공유
   - 스킬 파일을 Git에 커밋해두면, 팀원 누구나 어떤 에이전트를 쓰든 같은 규칙을 참조
   - "우리 팀은 이렇게 변환한다"를 코드처럼 관리

3. 변환 범위가 다를 때
   - AWS Transform CLI: 대규모 일괄 변환, 캠페인 관리, 검증 루프
   - 코딩 에이전트: 새 코드 작성 시 규칙 준수, 소규모 수정

정리하면, AWS Transform CLI는 "대규모 변환 실행기"이고, 스킬 파일을 다른 에이전트에 공유하는 건 "일상 개발에서도 같은 규칙을 적용"하기 위한 것입니다.

꼭 다른 에이전트에서 써야 하는 건 아니에요. AWS Transform CLI만으로도 충분합니다. 다만 선택지가 있다는 거죠.

더 궁금한 점 있으시면 말씀해주세요!


> 반대로 너를 써야 할 이유가? 예를 들어 claude code 에서 그라비톤  변환하면 되지 않아?


ATX: 솔직한 질문이네요. 차이점을 정리하면:

AWS Transform CLI를 써야 하는 이유:

1. 검증 루프가 내장되어 있습니다
   - 변환 후 빌드/테스트를 자동으로 돌리고, 실패하면 수정하고 다시 검증
   - 단순히 코드를 바꾸는 게 아니라 "동작하는 상태"까지 보장하려 합니다

2. 대규모 일괄 처리
   - 리포지토리 100개에 같은 변환을 적용하는 캠페인 기능
   - 웹 앱에서 진행 상황 모니터링

3. 지속적 학습
   - 실행할 때마다 피드백을 학습해서 다음 실행 품질이 올라감
   - 같은 변환을 여러 프로젝트에 반복 적용할수록 정확도 향상

4. AWS Managed 변환 제공
   - AWS가 검증하고 유지보수하는 사전 제작 변환 33개
   - 직접 규칙을 만들 필요 없이 바로 사용 가능

5. 변환 정의의 체계적 관리
   - 버전 관리, 드래프트/게시, 태그, 팀 공유
   - Knowledge Items로 학습 내용 축적

반면 Claude Code로 "Graviton 전환해줘"라고 하면:
- 그때그때 AI가 알아서 하는 것이므로 일관성 보장이 어렵고
- 검증 루프가 자동화되어 있지 않고
- 학습이 축적되지 않고
- 100개 리포에 같은 품질로 반복 적용하기 어렵습니다

한 프로젝트 한 번 변환이면 Claude Code로도 충분할 수 있어요. 하지만 반복적이고 대규모이며 품질 일관성이 중요하다면 AWS Transform CLI가 적합합니다.

```


