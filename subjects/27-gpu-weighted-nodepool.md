## 카펜터 가중치 기반 노드풀로 비용, 성능, ICE 동시에 잡기 — GPU Spot 실전 사례 ##

* "ICE(Insufficient Capacity Error, 용량 부족 에러)"

### Backgroud ###

* 원래: g4dn(T4) 사용 — 물량이 가장 많아 Spot 확보가 쉬웠음
* 변화: 모델에 어텐션 연산 추가 → T4로는 느림 → 더 빠른 GPU 필요
* 현재 요건: 어텐션 가속이 되는 g5/g6/g7을 Spot으로 우선 사용, 이게 확보 안 되면 배치 장애 → 물량 많은 g4dn Spot으로 fallback

-> 기술적으로 g4dn=T4/Turing은 FlashAttention-2 미지원, g5/g6는 Ampere/Ada라 지원 

-> 리전마다 별도의 eks 클러스터를 별도로 구성하여 (서로 다른 인스턴스 타입의 노드풀을 가짐 -> 왜.. 리전마다 잔여 인스턴스 타입들이 틀려서), S3 를 버킷 하부의 디렉토리 레벨(샤드) 로 복재하여 구성할 수 있으나, 이는 추가적인 eks 비용할생과 운영 복잡성을 증가시키므로 권장되는 아키텍처는 아니다.. 또한 S3 복제비용(api, nat, CRR 등)이 추가적으로 발생.

### 들어가며 ###

GPU는 비쌉니다. 그래서 많은 팀이 배치(batch) 추론·학습 워크로드를 **Spot 인스턴스**로 돌립니다. 최대 90%까지 저렴하니까요. 문제는 "빠른 GPU일수록 Spot 물량이 적다"는 현실입니다. 원하는 최신 GPU의 Spot 용량이 없으면 배치는 그대로 멈추고, 이는 곧 장애로 이어집니다.

이 글에서는 한 고객이 **Karpenter의 가중치 기반 노드풀(Weighted NodePools)** 로 "빠른 GPU를 우선 쓰되, 없으면 물량 많은 GPU로 자동 fallback"하는 구조를 만들어 **비용·성능·가용성**을 동시에 잡은 사례를 소개합니다.

### 고객의 여정 ###

### 1단계: g4dn으로 시작 — "물량"이 이유였다

이 고객은 처음에 **g4dn(NVIDIA T4)** 인스턴스로 배치를 운영했습니다. T4가 특별히 빨라서가 아니라, **Spot 물량이 가장 많아 안정적으로 확보**할 수 있었기 때문입니다. 배치는 물량이 곧 안정성이니까요.

### 2단계: 어텐션 연산이 추가되다

모델이 고도화되면서 **어텐션(attention) 연산**이 추가됐습니다. 그런데 여기서 병목이 터집니다.

**T4(Turing 아키텍처)는 FlashAttention 같은 최신 어텐션 커널의 가속을 제대로 받지 못합니다.** FlashAttention-2는 Ampere 세대(이상)를 전제로 하기 때문에, T4에서는 최적화되지 않은 느린 경로로 어텐션이 돌아갑니다. 결과적으로 배치 시간이 늘어지고, 처리량이 떨어졌습니다.

### 3단계: 더 빠른 GPU가 필요해졌다 ###

그래서 어텐션 가속이 되는 최신 세대 GPU가 필요해졌습니다.

| 인스턴스 | GPU | 아키텍처 | 어텐션 가속 |
|----------|-----|----------|-------------|
| g4dn | T4 | Turing | 사실상 미지원 (느린 경로) |
| g5 | A10G | Ampere | FlashAttention-2 지원 |
| g6 | L4 | Ada Lovelace | FlashAttention-2 지원 |
| g7 | (최신 세대) | 최신 | 지원 |

이제 **g5/g6/g7이 "선호 대상"**이 됐습니다. 문제는 이 최신 GPU들의 Spot 물량이 g4dn만큼 넉넉하지 않다는 것. 최신 GPU Spot이 없다고 배치를 멈출 수는 없습니다.

### 해법: 가중치로 "선호"와 "안전망"을 나눈다 ###

핵심 아이디어는 단순합니다.

> **빠른 어텐션 GPU(g5/g6/g7)를 높은 우선순위로 먼저 쓰고, Spot 확보가 안 되면 물량 많은 g4dn으로 자동 fallback해서 배치가 절대 멈추지 않게 한다.**

Karpenter NodePool의 `weight` 필드(0~100, 높을수록 우선)를 이용해 두 계층으로 나눕니다.

#### 1순위: 어텐션 가속 GPU (Spot, 선호) ####

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: gpu-attention-spot
spec:
  weight: 100                     # 최우선: 어텐션 가속되는 최신 GPU
  template:
    spec:
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]
        - key: karpenter.k8s.aws/instance-family
          operator: In
          values: ["g5", "g6", "g7"]   # 어텐션 가속 세대
      taints:
        - key: nvidia.com/gpu
          effect: NoSchedule
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: gpu
  limits:
    nvidia.com/gpu: 100
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
```
g5/g6/g7을 하나의 풀로 묶은 것이 포인트입니다. Karpenter의 Spot 할당은 여러 인스턴스 타입에 걸쳐 가장 여유 있는 풀을 고르므로, 세대를 묶어두면 Spot 중단(interruption) 위험이 분산되고 확보 성공률이 올라갑니다.

#### 2순위: g4dn (Spot, 물량 안전망) ####

```
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: gpu-g4dn-fallback
spec:
  weight: 10                      # 안전망: 물량 많은 g4dn
  template:
    spec:
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]
        - key: karpenter.k8s.aws/instance-family
          operator: In
          values: ["g4dn"]
      taints:
        - key: nvidia.com/gpu
          effect: NoSchedule
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: gpu
  limits:
    nvidia.com/gpu: 200
```

weight: 100인 어텐션 GPU 풀이 항상 먼저 시도되고, 최신 GPU Spot 용량이 없거나 중단되면 Karpenter가 자동으로 weight: 10인 g4dn 풀로 넘어가 노드를 띄웁니다. 배치는 (느리더라도) 계속 돌아갑니다.

#### 왜 이게 비용·성능·가용성을 동시에 잡나

* 성능: 평상시에는 어텐션이 가속되는 g5/g6/g7이 먼저 선택돼 배치가 빠르게 끝납니다.
* 비용: 두 계층 모두 Spot이라 온디맨드 대비 큰 폭으로 절감합니다. 최신 GPU가 여유 있을 땐 그걸 저렴하게, 없을 땐 저렴한 g4dn을 씁니다.
* 가용성: 최신 GPU Spot이 말라도 물량 많은 g4dn이 받아주므로 배치가 멈추지 않습니다. "빠름"을 잠깐 포기하고 "돌아감"을 지키는 거죠.

트레이드오프였던 세 가지가 우선순위 문제로 바뀌는 게 핵심입니다.

#### 실전 팁

* fast 계층은 묶어서 다양성 확보. g5/g6/g7을 하나의 weight 100 풀에 넣으면 Spot 확보율이 올라갑니다. 굳이 "무조건 g7부터"가 필요하면 g7=100 / g6=90 / g5=80처럼 세분화할 수 있지만, 그만큼 Spot 다양성은 줄어듭니다. 성능 서열보다 확보 안정성이 중요하면 묶는 쪽을 추천합니다.
* g4dn 경로에 어텐션 fallback 코드 준비. T4에서는 FlashAttention이 안 도므로, 애플리케이션이 eager/기본 어텐션 구현으로 자동 전환되게 해두면 fallback 시에도 정상 동작합니다.
한 방울 더: 최후의 온디맨드 안전망. Spot이 전 계층에서 마르는 상황까지 대비하려면 weight: 1짜리 온디맨드 GPU 풀을 하나 더 두는 것도 방법입니다(비용 상한은 limits로 관리).
* taint/toleration으로 GPU 노드 보호. GPU 파드만 GPU 노드에 오도록 taint를 걸고, 배치 파드에 toleration을 부여하세요.
c* onsolidation 켜두기. Spot 회수·유휴 노드를 정리해 저비용 상태로 계속 수렴시킵니다.
* weight는 SLA가 아니라 "선호"다. 반드시 특정 세대에서만 돌아야 하는 워크로드라면 weight가 아니라 명시적 nodeSelector로 강제하세요.

### 마치며 ###
이 고객의 사례는 "빠른 자원 아니면 안 돼" vs "물량 있는 자원이라도 써야 해" 사이의 오래된 긴장을, weight 한 줄로 우선순위화해 풀어낸 이야기입니다. 어텐션 가속이 되는 g5/g6/g7을 우선 쓰되, Spot이 마르면 물량 넉넉한 g4dn이 배치를 지켜줍니다.

성능은 평상시에 챙기고, 장애는 안전망으로 막고, 비용은 Spot으로 내리고. 거창한 오토스케일링 로직 없이 NodePool 두 개와 weight만으로 시작할 수 있습니다.


----

## GPU 아키텍처 detection ###

* GPU 아키텍처 / 메모리 / GPU 이름 → PyTorch로 조회 가능 ✅
* EC2 인스턴스 타입(예: g5.xlarge) → PyTorch로는 불가능 ❌ (이건 AWS 메타데이터라 IMDS로 따로 조회해야 함)

### 1. PyTorch로 가능한 것 — GPU 정보 ###
```
import torch

if torch.cuda.is_available():
    i = torch.cuda.current_device()
    props = torch.cuda.get_device_properties(i)

    print("GPU 이름:", props.name)                    # 예: NVIDIA A10G / Tesla T4 / NVIDIA L4
    print("Compute Capability:", f"{props.major}.{props.minor}")  # 아키텍처 지표
    print("총 GPU 메모리(GB):", round(props.total_memory / 1024**3, 1))
    print("SM 개수:", props.multi_processor_count)
    print("GPU 개수:", torch.cuda.device_count())
else:
    print("CUDA GPU 없음")
```
아키텍처는 GPU 이름이 아니라 major.minor(compute capability)로 판별하는 게 정확하다.
```
CC	아키텍처	대표 GPU	AWS 인스턴스
7.5	Turing	T4	g4dn
8.0	Ampere	A100	p4
8.6	Ampere	A10G	g5
8.9	Ada Lovelace	L4 / L40S	g6 / g6e
9.0	Hopper	H100 / H200	p5 / p5e·p5en
10.x	Blackwell	B200	p6
```

### 2. PyTorch로 불가능한 것 — 인스턴스 타입 ###
인스턴스 타입은 CUDA가 모르는 정보라, EC2 인스턴스 메타데이터 서비스(IMDS) 에서 가져와야 한다. (IMDSv2 토큰 방식):

```
import requests

def get_ec2_instance_type():
    try:
        token = requests.put(
            "http://169.254.169.254/latest/api/token",
            headers={"X-aws-ec2-metadata-token-ttl-seconds": "60"},
            timeout=1,
        ).text
        return requests.get(
            "http://169.254.169.254/latest/meta-data/instance-type",
            headers={"X-aws-ec2-metadata-token": token},
            timeout=1,
        ).text
    except Exception:
        return None  # EC2가 아니거나 IMDS 차단된 환경

print("인스턴스 타입:", get_ec2_instance_type())  # 예: g5.2xlarge
```
EKS/파드 환경에서는 IMDS 접근이 막혀 있을 수 있다. 그럴 땐 Karpenter/Kubernetes가 노드에 붙여주는 라벨(node.kubernetes.io/instance-type, karpenter.k8s.aws/instance-family 등)을 파드에 Downward API 환경변수로 주입해서 읽는 방식이 더 안정적이다.

### 3. 런타임 GPU 감지로 어텐션 경로 분기 ###

fallback 이 동작하게 된 경우 어떤 GPU에 떨어졌는지에 따라 FlashAttention을 켤지 결정할 수 있다. FlashAttention-2는 Ampere(CC 8.0) 이상이 필요하니, g4dn(T4, CC 7.5)로 fallback되면 자동으로 일반 어텐션 경로로 내려가게 하면 된다.

```
import torch

def attention_backend():
    if not torch.cuda.is_available():
        return "cpu-eager"
    major, minor = torch.cuda.get_device_capability()
    cc = major + minor / 10
    if cc >= 8.0:           # Ampere 이상 → g5/g6/g7 등
        return "flash-attention-2"
    return "eager"          # Turing(T4)/g4dn fallback → 안전한 기본 경로

print("어텐션 백엔드:", attention_backend())
```

이렇게 해두면 "g5/g6/g7 Spot이면 FlashAttention, g4dn으로 fallback되면 eager"가 코드 레벨에서 자동으로 처리돼서, 앞서 얘기한 ICE fallback 시에도 배치가 죽지 않는 구성과 딱 맞물린다.

정리하면, GPU 이름·아키텍처(compute capability)·메모리는 PyTorch로 바로 조회 가능하고, 인스턴스 타입만 IMDS나 K8s 라벨로 별도 조회한다. 

> [!NOTE]
>
> `eager`는 어텐션을 최적화된 fused 커널 없이, PyTorch 기본 연산으로 그대로 계산하는 방식이다. HuggingFace의 attn_implementation="eager"와 같은 개념이다.
> * FlashAttention / SDPA(flash): softmax·matmul을 하나의 커널로 융합(fuse), N×N 어텐션 행렬을 메모리에 안 만듦 → 빠르고 메모리 절약
> * eager: softmax(QKᵀ/√d) @ V를 단계별 PyTorch 연산으로 순진하게(naive) 계산 → N×N 행렬을 실제로 메모리에 만듦 → 느리고 메모리 많이 씀
> 즉 eager는 "특별한 가속 커널을 안 쓰는 기본 구현"이라는 의미이다.


## attention 가속 설정 ##

### 1. HuggingFace Transformers — 가장 흔한 케이스 ###

모델을 로드할 때 attn_implementation 인자에 넘겨서 바인딩한다.

```
from transformers import AutoModelForCausalLM
import torch

def hf_attn_impl():
    if not torch.cuda.is_available():
        return "eager"
    major, minor = torch.cuda.get_device_capability()
    cc = major + minor / 10
    if cc >= 8.0:            # Ampere+ (g5/g6/g7) → FlashAttention-2
        return "flash_attention_2"
    return "sdpa"            # T4(g4dn) 등 → PyTorch SDPA (안전한 fallback)

model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Llama-3.1-8B",
    torch_dtype=torch.bfloat16,
    attn_implementation=hf_attn_impl(),   # ← 여기서 바인딩
).cuda()
```
HF가 인식하는 값은 "flash_attention_2", "sdpa", "eager" 세 가지이다.
즉 별도의 "바인딩 함수"가 있는 게 아니라, from_pretrained(..., attn_implementation=...) 인자가 바인딩 지점이다.

### 2. PyTorch 네이티브 SDPA — 컨텍스트 매니저로 바인딩 ###
직접 F.scaled_dot_product_attention을 쓰는 코드라면, 백엔드를 컨텍스트 매니저로 강제한다.

```
import torch
import torch.nn.functional as F
from torch.nn.attention import sdpa_kernel, SDPBackend

def sdpa_backends():
    major, _ = torch.cuda.get_device_capability()
    if major >= 8:   # Ampere+
        return [SDPBackend.FLASH_ATTENTION, SDPBackend.EFFICIENT_ATTENTION]
    return [SDPBackend.EFFICIENT_ATTENTION, SDPBackend.MATH]  # T4 fallback

with sdpa_kernel(sdpa_backends()):          # ← 이 블록 안의 SDPA 호출에 바인딩
    out = F.scaled_dot_product_attention(q, k, v)
```    
여기서는 "어느 함수에 바인딩"이 아니라, sdpa_kernel(...) 블록 안에서 실행되는 scaled_dot_product_attention 호출에 바인딩.

### 3. 직접 만든 어텐션 모듈 — 분기(dispatch)로 바인딩 ###

flash_attn 라이브러리를 직접 호출하는 커스텀 어텐션이라면, forward 안에서 백엔드에 따라 갈라주면 된다.

```
import torch.nn as nn
import torch.nn.functional as F

class Attention(nn.Module):
    def __init__(self):
        super().__init__()
        self.backend = attention_backend()   # 초기화 때 1회 결정

    def forward(self, q, k, v):
        if self.backend == "flash-attention-2":
            from flash_attn import flash_attn_func
            return flash_attn_func(q, k, v)   # ← 여기서 바인딩
        return F.scaled_dot_product_attention(q, k, v)  # eager/fallback 경로
```
attention_backend()는 "결정"만 하고, 실제 "바인딩"은 다음 중 하나에서 발생한다. 


### 4. 사전 준비 (빌드 의존성) ###

flash-attn은 CUDA 커널을 컴파일해서 설치하므로, 순서가 중요:

```
pip install torch          # flash-attn보다 먼저 (설치돼 있어야 함)
pip install packaging ninja
pip install flash-attn --no-build-isolation
```
* torch 먼저: flash-attn 빌드가 설치된 torch 버전을 참조.
* ninja: 없으면 컴파일이 수십 분~몇 시간 걸릴 수 있어요. ninja를 깔면 병렬 빌드로 훨씬 빨라짐.
* nvcc(CUDA Toolkit): 소스 빌드 시 필요합니다. 다만 최근에는 조건이 맞으면 prebuilt wheel을 받아 빌드를 건너뛰기도 함.

#### 설치 시 흔한 주의점 ####
* GPU 요구사항: FlashAttention-2는 Ampere(sm_80) 이상만 지원. 앞서 얘기한 대로 g4dn(T4, sm_75)에서는 설치돼도 실행 시 에러납니다. → 그래서 코드의 else 분기(SDPA)로 내려간다.
* 버전 궁합: torch / CUDA / flash-attn 버전이 맞아야 wheel을 받는다.. 안 맞으면 소스 빌드로 넘어가고, 이때 시간이 오래 걸리거나 실패할 수 있다.
* 컨테이너/CI: 빌드 시간 때문에 Dockerfile에서는 보통 미리 빌드하거나, PyTorch 공식 이미지(nvidia/pytorch 등 flash-attn 포함)나 사전 빌드 wheel을 쓰는 걸 권장


### 5. 컨테이너 이미지 준비 ###

GPU 드라이버는 AMI(호스트) 레벨, CUDA 런타임·PyTorch·flash-attn은 컨테이너 레벨이다.. flash-attn은 AMI에 기본으로 깔려 있지 않다.

#### 레이어별 정리 ####
```
레이어	무엇이 사나	어디에
호스트/AMI	NVIDIA GPU 드라이버, NVIDIA Container Toolkit, (EKS면) device plugin	AMI 레벨 ✅
컨테이너 이미지	CUDA 런타임, cuDNN, PyTorch, flash-attn	컨테이너 안 ✅
```
* 드라이버: 커널 모듈이라 호스트에 있어야 하고, 컨테이너가 공유해서 쓴다.
* CUDA 툴킷/런타임 + PyTorch + flash-attn: 보통 컨테이너 이미지 안에 넣는다. (컨테이어 이식성의 핵심)
  
#### AWS ####
Deep Learning AMI(DLAMI) / EKS GPU-optimized AMI
```
드라이버는 미리 깔려 있고, G 타입 인스턴스에 이 AMI를 쓰면 드라이버 설치는 신경 쓰지 않아도 된다.
하지만 flash-attn은 AMI에 없다.. flash-attn은 파이썬/CUDA 레벨 라이브러리라 컨테이너(또는 그 안의 venv)에서 설치해야 한다.
```

컨테이너로 돌린다면 (EKS/Karpenter 시나리오)

* 호스트(GPU AMI): 드라이버 + Container Toolkit + NVIDIA device plugin → GPU 노출
* 앱 컨테이너: CUDA 런타임 + PyTorch + flash-attn을 이미지에 빌드해 넣어야 함

즉 pip install flash-attn은 Dockerfile 안에서 하는 것이다.직접 빌드하기 싫으면 flash-attn이 사전 설치된 베이스 이미지를 쓰면 된다.
(이 경우 컨테이너 안에 이미 있으니 별도 설치 불필요)
* NGC PyTorch 컨테이너 (nvcr.io/nvidia/pytorch:xx.xx-py3) — flash-attn 등 다수 포함
* AWS Deep Learning Containers(DLC) 일부 버전

#### 주의점 ####
* 드라이버 ↔ CUDA 버전 궁합: 호스트 드라이버 버전이 컨테이너의 CUDA 런타임을 지원해야 합니다. 드라이버가 컨테이너 CUDA보다 같거나 새 버전이어야 한다.(CUDA forward compatibility).
* g4dn(T4)에서는 flash-attn 무의미: 어느 레이어에 깔든 T4(sm_75)는 FlashAttention-2 실행이 안 된다. 그래서 앞서 만든 SDPA/eager fallback 필요.
  
#### Dockerfile ####

flash-attn은 빌드에 nvcc가 필요하지만 런타임엔 불필요하므로, 빌드는 devel 이미지에서 하고 결과만 런타임 이미지로 복사해 최종 이미지를 가볍게 만든다.(멀티스테이지 권장)

```
# ---------- 1) build stage: flash-attn 컴파일 ----------
FROM pytorch/pytorch:2.4.0-cuda12.1-cudnn9-devel AS builder
# devel 이미지 = nvcc 포함 (flash-attn 빌드에 필요)

ENV DEBIAN_FRONTEND=noninteractive
# 빌드 대상 아키텍처만 지정해 빌드 시간 단축
# 8.0=A100(p4), 8.6=A10G(g5), 8.9=L4(g6), 9.0=H100(p5)  → T4(7.5)는 미지원이라 제외
ENV TORCH_CUDA_ARCH_LIST="8.0;8.6;8.9;9.0"
ENV MAX_JOBS=4

RUN pip install --no-cache-dir packaging ninja
# ninja가 있어야 병렬 빌드로 훨씬 빠름
RUN pip install --no-cache-dir flash-attn==2.6.3 --no-build-isolation

# ---------- 2) runtime stage: 실행에 필요한 것만 ----------
FROM pytorch/pytorch:2.4.0-cuda12.1-cudnn9-runtime
# runtime 이미지 = nvcc 없음, 크기 작음. 드라이버는 노드에서 제공됨.

# builder에서 설치된 flash-attn 등 site-packages 복사
COPY --from=builder /opt/conda/lib/python3.11/site-packages /opt/conda/lib/python3.11/site-packages

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt   # transformers 등 앱 의존성
COPY . .

CMD ["python", "serve.py"]
```
site-packages 경로의 파이썬 버전(예: python3.11)은 베이스 이미지에 맞게 확인. docker run --rm pytorch/pytorch:2.4.0-cuda12.1-cudnn9-runtime python -c "import sys;print(sys.path)"로 확인

#### requirements.txt ####
requirements.txt는 torch와 flash-attn을 빼는 게 핵심이다. 이 둘은 이미 베이스 이미지(그리고 빌드 스테이지)에서 제공되므로, 여기에 다시 넣으면 torch가 재설치·업그레이드되면서 flash-attn과 버전이 깨질 수 있다.
```
# ⚠️ torch / flash-attn 은 여기 넣지 않습니다.
#    - torch: 베이스 이미지(pytorch/pytorch:*)가 제공
#    - flash-attn: 빌드 스테이지에서 설치 → runtime으로 복사됨
#    여기에 다시 넣으면 torch가 재설치되어 flash-attn ABI가 깨질 수 있음

# --- 모델 로딩/추론 ---
transformers==4.44.2
accelerate==0.34.2
safetensors==0.4.5
huggingface-hub==0.25.1
sentencepiece==0.2.0          # 일부 토크나이저(LLaMA 등)에 필요

# --- 인스턴스 타입 조회(IMDS) ---
requests==2.32.3

# --- 서빙 (API로 띄운다면) ---
fastapi==0.115.0
uvicorn[standard]==0.30.6
pydantic==2.9.2
```
* HTTP API 없이 배치 스크립트만 돌린다면 → fastapi/uvicorn/pydantic 줄 삭제
* vLLM 같은 추론 엔진을 쓴다면 → vLLM이 자체적으로 torch·flash-attn·transformers 버전을 강하게 고정하므로, 이 requirements 대신 vLLM 버전만 명시하고 베이스 이미지도 vLLM 권장 조합으로 사용.
* datasets에서 데이터 로드한다면 → datasets==2.21.0 추가
---
* 버전 고정(pinning) 권장: 재빌드 시 재현성 확보. 특히 transformers는 attn_implementation="flash_attention_2" 인자를 지원하는 버전(4.36+)이어야 합니다. 위 4.44.2는 충족해요.
* transformers ↔ flash-attn 궁합: transformers가 flash-attn을 호출할 때 API가 맞아야 하므로, transformers를 너무 올드하게 두지 마세요.
* torch 의존 패키지 주의: accelerate 등이 torch를 끌고 올 수 있는데, 이미 설치돼 있으면 pip이 건너뜁니다. 그래도 확실히 하려면 pip install --no-deps로 개별 관리하거나, 빌드 로그에서 torch가 재설치되지 않는지 확인하세요.

#### 빌드가 귀찮다면: flash-attn 포함 베이스 이미지 ####
직접 빌드를 피하고 싶으면 flash-attn이 이미 들어있는 NGC 이미지를 쓰면 된다.
```
FROM nvcr.io/nvidia/pytorch:24.07-py3   # flash-attn 등 사전 포함
WORKDIR /app
COPY . .
CMD ["python", "serve.py"]
```

#### 샘플 파드스팩 ####
이미지 하나로 g5/g6/g7 ↔ g4dn 모두 커버하고, 스케줄링만 노드풀에 맡긴다.
```
spec:
  containers:
    - name: infer
      image: <your-ecr>/attn-app:latest
      resources:
        limits:
          nvidia.com/gpu: 1        # device plugin이 노출한 GPU 요청
  tolerations:
    - key: nvidia.com/gpu          # GPU 노드 taint 허용
      operator: Exists
      effect: NoSchedule
```


