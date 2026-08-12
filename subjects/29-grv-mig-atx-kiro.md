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


폴더를 하나 열어주시면 위 샘플을 실제 파일로 만들고, Docker 기반 스캔 도구까지 돌려서 진짜 리포트를 뽑아 드릴게요. 어느 방법으로 진행할까요?
