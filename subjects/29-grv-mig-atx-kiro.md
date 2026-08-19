## Graviton  in Days vs Months with AWS Transform custom, Claude Skills and Kiro Power ## 

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
