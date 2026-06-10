"""
Proxy routes to the AirSense ML API (port 5000).

All endpoints are auth-protected — the frontend calls these instead of
hitting the ML API directly in production.
"""

from __future__ import annotations

import os
from typing import Any

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import JSONResponse

from app.api.deps import get_current_user

ML_API_URL = os.getenv("ML_API_URL", "http://localhost:5000")
TIMEOUT = 30.0

router = APIRouter()


async def _ml_get(path: str, params: dict | None = None) -> Any:
    async with httpx.AsyncClient() as client:
        try:
            resp = await client.get(f"{ML_API_URL}{path}", params=params, timeout=TIMEOUT)
        except httpx.ConnectError:
            raise HTTPException(status_code=503, detail="ML service unavailable.")
    if resp.status_code >= 500:
        raise HTTPException(status_code=502, detail="ML service error.")
    return resp.json()


async def _ml_post(path: str, body: dict) -> Any:
    async with httpx.AsyncClient() as client:
        try:
            resp = await client.post(f"{ML_API_URL}{path}", json=body, timeout=TIMEOUT)
        except httpx.ConnectError:
            raise HTTPException(status_code=503, detail="ML service unavailable.")
    if resp.status_code >= 500:
        raise HTTPException(status_code=502, detail="ML service error.")
    return resp.json()


@router.get("/health")
async def ml_health(_: Any = Depends(get_current_user)):
    return await _ml_get("/health")


@router.post("/recommend")
async def ml_recommend(body: dict, _: Any = Depends(get_current_user)):
    return await _ml_post("/recommend", body)


@router.post("/predict/aqi")
async def ml_predict_aqi(body: dict, _: Any = Depends(get_current_user)):
    return await _ml_post("/predict/aqi", body)


@router.post("/classify/category")
async def ml_classify(body: dict, _: Any = Depends(get_current_user)):
    return await _ml_post("/classify/category", body)


@router.get("/forecast")
async def ml_forecast(
    steps: int = Query(24, ge=1, le=1000),
    _: Any = Depends(get_current_user),
):
    return await _ml_get("/forecast", params={"steps": steps})


@router.post("/forecast")
async def ml_forecast_post(body: dict, _: Any = Depends(get_current_user)):
    return await _ml_post("/forecast", body)


@router.post("/predict/pollutants")
async def ml_predict_pollutants(body: dict, _: Any = Depends(get_current_user)):
    return await _ml_post("/predict/pollutants", body)


@router.post("/sensitivity")
async def ml_sensitivity(body: dict, _: Any = Depends(get_current_user)):
    return await _ml_post("/sensitivity", body)


@router.get("/feature_importance")
async def ml_feature_importance(
    model_key: str = Query("xgboost_reg"),
    top: int = Query(15, ge=1, le=50),
    _: Any = Depends(get_current_user),
):
    return await _ml_get("/feature_importance", params={"model_key": model_key, "top": top})
