* https://aws.amazon.com/ko/blogs/aws/amazon-bedrock-introduces-new-advanced-prompt-optimization-and-migration-tool/



프롬프트 튜닝은 이제 그만, Bedrock이 알아서 최적화해준다
Amazon Bedrock 고급 프롬프트 최적화 & 마이그레이션 도구 살펴보기
프롬프트 엔지니어링을 해본 사람이라면 다 안다. "이 문장을 조금 바꾸면 더 좋아지지 않을까?" 하며 하루 종일 프롬프트를 만지작거리다 보면, 정작 정량적으로 좋아졌는지 확신이 안 선다. 게다가 새 모델이 나올 때마다 기존 프롬프트가 그대로 잘 먹힐지도 알 수 없어서, 모델 교체는 늘 조심스럽다.

Amazon Bedrock의 고급 프롬프트 최적화(Advanced Prompt Optimization) 는 바로 이 지점을 겨냥한 도구다. 평가 지표만 정해두면, Bedrock이 지표 기반 피드백 루프를 돌며 프롬프트를 자동으로 다시 쓰고, 원본 대비 얼마나 좋아졌는지 최대 5개 모델에서 동시에 비교해준다.

두 가지 시나리오
1) 모델 마이그레이션 새 모델로 갈아탈 때 가장 무서운 건 "기존에 잘 되던 게 깨지는 것(regression)"이다. 이 도구는 현재 쓰는 모델을 기준선으로 두고, 후보 모델 4개까지 나란히 비교할 수 있다. 알려진 유스케이스에서 성능이 떨어지지 않는지 확인하면서, 부진했던 작업은 오히려 개선하는 식으로 안전하게 이전할 수 있다.

2) 현재 모델 성능 개선 모델을 안 바꿔도 된다. 지금 쓰는 모델 하나만 골라서 최적화 전/후를 비교하면, 같은 모델에서 더 나은 결과를 뽑아낼 수 있다.

어떻게 동작하나
입력으로 다음을 넣는다.

프롬프트 템플릿
변수에 들어갈 예시 사용자 입력
정답(ground truth) — 선택 사항
최적화 방향을 안내할 평가 지표
그러면 Bedrock이 프롬프트와 예시 데이터를 대상 모델들에 보내고, 응답을 여러분이 정한 지표로 평가한 뒤, 피드백 루프 안에서 프롬프트를 다시 쓴다. 결과로는 원본/최종 프롬프트 템플릿, 평가 점수, 비용 추정치, 지연시간이 나온다.

특히 png, jpg, pdf 같은 멀티모달 입력을 지원해서 문서 분석이나 이미지 분석용 프롬프트도 최적화할 수 있다는 점이 눈에 띈다.

평가 방식 3가지
프롬프트 템플릿마다 하나씩 고를 수 있고, 한 작업(job) 안에 여러 템플릿을 넣어 각각 다른 방식을 섞어 쓸 수도 있다.

방식	언제 쓰나	동작
Lambda 함수	정확도, F1, JSON 매칭처럼 딱 떨어지는 지표가 있을 때	직접 짠 compute_score 로직으로 출력과 정답을 프로그램적으로 비교
LLM-as-a-Judge	요약·생성·추론 설명처럼 정답이 열려 있을 때	루브릭(기준 + 점수 척도)을 정의하면 심판 모델이 점수와 이유를 반환. 기본 모델은 Claude Sonnet 4.6
Steering criteria	원하는 품질(브랜드 톤, 포맷, 안전 제약)은 알지만 심판 프롬프트를 직접 쓰긴 부담될 때	자연어 기준만 적으면 기본 LLM 심판이 이를 반영해 종합 평가
시작하기
Bedrock 콘솔의 Advanced Prompt Optimization 페이지에서 Create prompt optimization을 선택하고, 최적화할 모델을 최대 5개 고른다. 프롬프트 템플릿은 JSONL 포맷으로 준비하는데(한 줄에 JSON 객체 하나), 파일을 직접 업로드하거나 S3에서 불러올 수 있다. 결과가 저장될 S3 위치를 지정하고 Create optimization을 누르면 끝이다. 콘솔 대신 CreateAdvancedPromptOptimizationJob API로도 실행할 수 있다.

제공 지역과 요금
서울을 포함해 미국(버지니아 북부·오하이오·오레곤), 아시아 태평양(뭄바이·싱가포르·시드니·도쿄), 캐나다 중부, 유럽(프랑크푸르트·아일랜드·런던·취리히), 남미(상파울루) 등에서 오늘부터 사용할 수 있다. 별도 요금은 없고, 최적화 과정에서 소비한 Bedrock 모델 추론 토큰만큼 일반 추론과 동일한 단가로 과금된다.

마치며
프롬프트를 손으로 계속 조정하는 대신, "무엇이 좋은 응답인가"를 지표로 정의해두면 나머지는 Bedrock이 알아서 반복 최적화해준다. 감(感)에 의존하던 프롬프트 튜닝을 측정 가능한 엔지니어링 과정으로 바꿔준다는 점에서, 특히 모델 교체가 잦은 팀이라면 한 번 써볼 만하다.

이제 실전 예제야.

1. JSONL 프롬프트 템플릿 예제
세 가지 평가 방식을 각각 보여주는 3개의 템플릿을 담았어. JSONL이라 실제 파일에서는 각 객체가 반드시 한 줄에 있어야 한다는 점 주의. (아래는 읽기 쉽게 들여쓰기했지만, 실제로는 한 줄로 펼쳐야 함)

json

{"version":"bedrock-2026-05-14","templateId":"support-ticket-classifier","promptTemplate":"You are a support triage assistant. Classify the following ticket into exactly one category: BILLING, TECHNICAL, ACCOUNT, or OTHER. Respond with only the category name.\n\nTicket: {{ticket_text}}","customEvaluationMetricLabel":"exact_category_match","evaluationMetricLambdaArn":"arn:aws:lambda:ap-northeast-2:123456789012:function:prompt-opt-scorer","evaluationSamples":[{"inputVariables":[{"ticket_text":"I was charged twice for my subscription this month."}],"referenceResponse":"BILLING"},{"inputVariables":[{"ticket_text":"The app crashes every time I open the settings page."}],"referenceResponse":"TECHNICAL"},{"inputVariables":[{"ticket_text":"How do I change the email address on my profile?"}],"referenceResponse":"ACCOUNT"}]}
{"version":"bedrock-2026-05-14","templateId":"meeting-summarizer","promptTemplate":"Summarize the following meeting transcript into 3-5 concise bullet points capturing decisions and action items.\n\nTranscript: {{transcript}}","customEvaluationMetricLabel":"summary_quality","customLLMJConfig":{"customLLMJPrompt":"You are evaluating a meeting summary. Rate it 1-5 on: (1) captures all key decisions, (2) captures action items with owners, (3) conciseness, (4) no hallucinated content. Return the average score and a one-sentence rationale.","customLLMJModelId":"anthropic.claude-sonnet-4-6-20260514-v1:0"},"evaluationSamples":[{"inputVariables":[{"transcript":"Alice: We should ship the beta by Friday. Bob: I'll finish the API by Wednesday. Carol: I'll handle QA Thursday."}],"referenceResponse":"- Decision: ship beta by Friday\n- Bob: finish API by Wednesday\n- Carol: run QA on Thursday"}]}
{"version":"bedrock-2026-05-14","templateId":"product-description-writer","promptTemplate":"Write a product description for the following item.\n\nProduct: {{product_name}}\nFeatures: {{features}}","steeringCriteria":["Friendly and energetic brand voice","Between 40 and 80 words","No exaggerated superlatives like 'best ever'","Ends with a clear call to action"],"evaluationSamples":[{"inputVariables":[{"product_name":"AeroBottle 500ml","features":"insulated, leak-proof, keeps drinks cold 24h"}]}]}
첫 번째(support-ticket-classifier): Lambda 방식. 카테고리 정확 일치를 채점.
두 번째(meeting-summarizer): LLM-as-a-Judge. 커스텀 루브릭으로 요약 품질 평가.
세 번째(product-description-writer): Steering criteria. 자연어 기준만 나열.
참고: evaluationMetricLambdaArn은 여러분 실제 리전/계정 ARN으로 바꿔야 하고, 멀티모달 입력을 쓰려면 inputVariablesMultimodal에 S3 경로와 타입(PDF/IMAGE)을 넣으면 돼.

2. Lambda 스코어링 함수
첫 번째 템플릿(분류 작업)에 대응하는 채점 Lambda 예제야. 핵심은 compute_score 로직으로, 모델 출력을 정답(reference)과 비교해서 0.0~1.0 점수를 돌려준다.

python

"""
Bedrock Advanced Prompt Optimization - custom scoring Lambda.

Bedrock invokes this function for each evaluation sample, passing the
model's response and the reference answer. Return a numeric score in [0, 1].
"""
import json
import re

def normalize(text: str) -> str:
    """Lowercase, strip, and collapse whitespace for robust comparison."""
    return re.sub(r"\s+", " ", text.strip().lower())

def compute_score(model_output: str, reference: str) -> float:
    """
    Exact-category match scorer.

    Returns 1.0 if the model output contains the reference category label,
    else 0.0. Adjust this logic for your own metric (F1, JSON match, etc.).
    """
    if not reference:
        return 0.0

    predicted = normalize(model_output)
    expected = normalize(reference)

    # The model is asked to reply with only the category, but be lenient:
    # accept the answer if the expected label appears as a whole word.
    return 1.0 if re.search(rf"\b{re.escape(expected)}\b", predicted) else 0.0

def lambda_handler(event, context):
    """
    Expected event shape (per Bedrock prompt-optimization scoring contract):
    {
        "modelResponse": "<the model's generated output>",
        "referenceResponse": "<ground-truth answer, may be empty>",
        "inputVariables": { ... }   # original inputs, if you need them
    }

    Must return: {"score": <float between 0 and 1>}
    """
    # Bedrock may deliver the payload as a JSON string or a dict.
    if isinstance(event, str):
        event = json.loads(event)

    model_output = event.get("modelResponse", "") or ""
    reference = event.get("referenceResponse", "") or ""

    score = compute_score(model_output, reference)

    return {
        "score": score,
        # Optional: include reasoning/metadata for debugging in the results.
        "details": {
            "predicted": model_output[:200],
            "expected": reference,
        },
    }
다른 지표 예시: 구조화된 JSON 일치 채점
분류가 아니라 JSON 출력을 검증한다면 compute_score만 이렇게 바꾸면 돼:

python

def compute_score(model_output: str, reference: str) -> float:
    """Score = fraction of reference keys whose values match exactly."""
    try:
        predicted = json.loads(model_output)
        expected = json.loads(reference)
    except (json.JSONDecodeError, TypeError):
        return 0.0  # invalid JSON gets zero

    if not expected:
        return 0.0

    matches = sum(
        1 for k, v in expected.items() if predicted.get(k) == v
    )
    return matches / len(expected)
배포 시 체크리스트
Lambda 실행 역할에 Bedrock이 이 함수를 호출할 수 있는 권한(리소스 기반 정책)을 붙였는지 확인.
함수를 프롬프트 최적화 job과 같은 리전에 배포.
타임아웃과 메모리는 채점 로직 복잡도에 맞게 조정 (단순 문자열 비교면 기본값으로 충분).
반환값의 score는 반드시 숫자여야 하고, 지표 방향(높을수록 좋음)이 일관되게 유지되도록.
