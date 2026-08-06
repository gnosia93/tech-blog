## 카펜터 가중치 기반 노드풀로 비용, 성능, ICE 동시에 잡기 — GPU Spot 실전 사례 ##

* "ICE(Insufficient Capacity Error, 용량 부족 에러)"

### Backgroud ###

* 원래: g4dn(T4) 사용 — 물량이 가장 많아 Spot 확보가 쉬웠음
* 변화: 모델에 어텐션 연산 추가 → T4로는 느림 → 더 빠른 GPU 필요
* 현재 요건: 어텐션 가속이 되는 g5/g6/g7을 Spot으로 우선 사용, 이게 확보 안 되면 배치 장애 → 물량 많은 g4dn Spot으로 fallback

 기술적으로 g4dn=T4/Turing은 FlashAttention-2 미지원, g5/g6는 Ampere/Ada라 지원 


### 들어가며 ###

GPU는 비쌉니다. 그래서 많은 팀이 배치(batch) 추론·학습 워크로드를 **Spot 인스턴스**로 돌립니다. 최대 90%까지 저렴하니까요. 문제는 "빠른 GPU일수록 Spot 물량이 적다"는 현실입니다. 원하는 최신 GPU의 Spot 용량이 없으면 배치는 그대로 멈추고, 이는 곧 장애로 이어집니다.

이 글에서는 한 고객이 **Karpenter의 가중치 기반 노드풀(Weighted NodePools)** 로 "빠른 GPU를 우선 쓰되, 없으면 물량 많은 GPU로 자동 fallback"하는 구조를 만들어 **비용·성능·가용성**을 동시에 잡은 사례를 소개합니다.

### 고객의 여정 ###

### 1단계: g4dn으로 시작 — "물량"이 이유였다

이 고객은 처음에 **g4dn(NVIDIA T4)** 인스턴스로 배치를 운영했습니다. T4가 특별히 빨라서가 아니라, **Spot 물량이 가장 많아 안정적으로 확보**할 수 있었기 때문입니다. 배치는 물량이 곧 안정성이니까요.

### 2단계: 어텐션 연산이 추가되다

모델이 고도화되면서 **어텐션(attention) 연산**이 추가됐습니다. 그런데 여기서 병목이 터집니다.

**T4(Turing 아키텍처)는 FlashAttention 같은 최신 어텐션 커널의 가속을 제대로 받지 못합니다.** FlashAttention-2는 Ampere 세대(이상)를 전제로 하기 때문에, T4에서는 최적화되지 않은 느린 경로로 어텐션이 돌아갑니다. 결과적으로 배치 시간이 늘어지고, 처리량이 떨어졌습니다.

### 3단계: 더 빠른 GPU가 필요해졌다

그래서 어텐션 가속이 되는 최신 세대 GPU가 필요해졌습니다.

| 인스턴스 | GPU | 아키텍처 | 어텐션 가속 |
|----------|-----|----------|-------------|
| g4dn | T4 | Turing | 사실상 미지원 (느린 경로) |
| g5 | A10G | Ampere | FlashAttention-2 지원 |
| g6 | L4 | Ada Lovelace | FlashAttention-2 지원 |
| g7 | (최신 세대) | 최신 | 지원 |

이제 **g5/g6/g7이 "선호 대상"**이 됐습니다. 문제는 이 최신 GPU들의 Spot 물량이 g4dn만큼 넉넉하지 않다는 것. 최신 GPU Spot이 없다고 배치를 멈출 수는 없습니다.

### 해법: 가중치로 "선호"와 "안전망"을 나눈다

핵심 아이디어는 단순합니다.

> **빠른 어텐션 GPU(g5/g6/g7)를 높은 우선순위로 먼저 쓰고, Spot 확보가 안 되면 물량 많은 g4dn으로 자동 fallback해서 배치가 절대 멈추지 않게 한다.**

Karpenter NodePool의 `weight` 필드(0~100, 높을수록 우선)를 이용해 두 계층으로 나눕니다.

#### 1순위: 어텐션 가속 GPU (Spot, 선호)

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

g5/g6/g7을 하나의 풀로 묶은 것이 포인트입니다. Karpenter의 Spot 할당은 여러 인스턴스 타입에 걸쳐 가장 여유 있는 풀을 고르므로, 세대를 묶어두면 Spot 중단(interruption) 위험이 분산되고 확보 성공률이 올라갑니다.

#### 2순위: g4dn (Spot, 물량 안전망) ###

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
