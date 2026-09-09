import cf from "cloudfront";

function handler(event) {
    // Reverse the preferred origin for approximately half of requests.
    // CloudFront retries the other VM if the preferred one is unavailable.
    cf.createRequestOriginGroup({
        originIds: Math.random() < 0.5
            ? ["web-a", "web-b"]
            : ["web-b", "web-a"],
        failoverCriteria: {
            statusCodes: [500, 502, 503, 504]
        }
    });
    return event.request;
}
