배경 잘 이해했어요. 정리하면 이런 그림이네요:

원래: g4dn(T4) 사용 — 물량이 가장 많아 Spot 확보가 쉬웠음
변화: 모델에 어텐션 연산 추가 → T4로는 느림 → 더 빠른 GPU 필요
현재 요건: 어텐션 가속이 되는 g5/g6/g7을 Spot으로 우선 사용, 이게 확보 안 되면 배치 장애 → 물량 많은 g4dn Spot으로 fallback

& 기술적으로 g4dn=T4/Turing은 FlashAttention-2 미지원, g5/g6는 Ampere/Ada라 지원 

# 가중치 기반 노드풀로 비용과 성능 동시에 잡기 — GPU Spot 실전 사례

## 들어가며

GPU는 비쌉니다. 그래서 많은 팀이 배치(batch) 추론·학습 워크로드를 **Spot 인스턴스**로 돌립니다. 최대 90%까지 저렴하니까요. 문제는 "빠른 GPU일수록 Spot 물량이 적다"는 현실입니다. 원하는 최신 GPU의 Spot 용량이 없으면 배치는 그대로 멈추고, 이는 곧 장애로 이어집니다.

이 글에서는 한 고객이 **Karpenter의 가중치 기반 노드풀(Weighted NodePools)** 로 "빠른 GPU를 우선 쓰되, 없으면 물량 많은 GPU로 자동 fallback"하는 구조를 만들어 **비용·성능·가용성**을 동시에 잡은 사례를 소개합니다.

## 고객의 여정

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

## 해법: 가중치로 "선호"와 "안전망"을 나눈다

핵심 아이디어는 단순합니다.

> **빠른 어텐션 GPU(g5/g6/g7)를 높은 우선순위로 먼저 쓰고, Spot 확보가 안 되면 물량 많은 g4dn으로 자동 fallback해서 배치가 절대 멈추지 않게 한다.**

Karpenter NodePool의 `weight` 필드(0~100, 높을수록 우선)를 이용해 두 계층으로 나눕니다.

### 1순위: 어텐션 가속 GPU (Spot, 선호)

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

