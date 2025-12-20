import openai
import json
from typing import Dict, Any
from ..core.config import settings


class PropertyValuator:
    def __init__(self):
        openai.api_key = settings.OPENAI_API_KEY
    
    async def estimate_value(self, property_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Estimate property value using AI
        """
        if not openai.api_key:
            return self._rule_based_valuation(property_data)
        
        prompt = self._create_valuation_prompt(property_data)
        
        try:
            response = await openai.ChatCompletion.acreate(
                model="gpt-3.5-turbo",  # Using 3.5 for cost efficiency
                messages=[
                    {"role": "system", "content": "You are a real estate valuation expert. Always respond with valid JSON."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.3,
                max_tokens=500
            )
            
            valuation_text = response.choices[0].message.content
            return self._parse_valuation_response(valuation_text, property_data)
            
        except Exception as e:
            print(f"AI valuation failed: {e}")
            return self._rule_based_valuation(property_data)
    
    def _create_valuation_prompt(self, property_data: Dict[str, Any]) -> str:
        return f"""
        Estimate the market value of this real estate property and provide analysis.
        
        Property Details:
        - Type: {property_data.get('property_type', 'residential')}
        - Location: {property_data.get('address', 'Unknown')}, {property_data.get('city', 'Unknown')}, {property_data.get('state', 'Unknown')}
        - Size: {property_data.get('square_feet', 0)} square feet
        - Bedrooms: {property_data.get('bedrooms', 0)}
        - Bathrooms: {property_data.get('bathrooms', 0)}
        - Year Built: {property_data.get('year_built', 0)}
        - Current Price: ${property_data.get('price', 0):,.2f}
        - Lot Size: {property_data.get('lot_size', 0)} sq ft
        - Amenities: {', '.join(property_data.get('amenities', []))}
        
        Provide your analysis in the following JSON format:
        {{
            "estimated_value": <estimated market value in dollars>,
            "confidence_score": <confidence score from 0-100>,
            "key_factors": ["factor1", "factor2", "factor3"],
            "price_range": {{
                "low": <lowest reasonable price>,
                "high": <highest reasonable price>
            }},
            "market_analysis": "<brief market analysis>",
            "recommendation": "<buy/sell/hold recommendation>"
        }}
        """
    
    def _parse_valuation_response(self, text: str, property_data: Dict[str, Any]) -> Dict[str, Any]:
        try:
            # Try to extract JSON from the response
            json_start = text.find('{')
            json_end = text.rfind('}') + 1
            json_str = text[json_start:json_end]
            result = json.loads(json_str)
            
            # Validate and add missing fields
            required_fields = ['estimated_value', 'confidence_score', 'key_factors']
            for field in required_fields:
                if field not in result:
                    result[field] = None
            
            return result
        except json.JSONDecodeError:
            return self._rule_based_valuation(property_data)
    
    def _rule_based_valuation(self, property_data: Dict[str, Any]) -> Dict[str, Any]:
        """Fallback rule-based valuation"""
        base_price_per_sqft = {
            'residential': 200,
            'commercial': 150,
            'industrial': 100,
            'land': 50
        }
        
        property_type = property_data.get('property_type', 'residential')
        sqft = property_data.get('square_feet', 1000)
        bedrooms = property_data.get('bedrooms', 0)
        bathrooms = property_data.get('bathrooms', 0)
        city = property_data.get('city', '').lower()
        
        # Base value
        base_value = base_price_per_sqft.get(property_type, 200) * sqft
        
        # Adjust for bedrooms/bathrooms
        room_adjustment = (bedrooms * 10000) + (bathrooms * 5000)
        
        # Adjust for location (simplified)
        location_multiplier = 1.0
        if 'new york' in city or 'san francisco' in city or 'los angeles' in city:
            location_multiplier = 1.5
        elif 'chicago' in city or 'miami' in city or 'seattle' in city:
            location_multiplier = 1.2
        
        estimated_value = (base_value + room_adjustment) * location_multiplier
        
        return {
            'estimated_value': round(estimated_value, 2),
            'confidence_score': 65,
            'key_factors': [
                f'Property type: {property_type}',
                f'Size: {sqft} sq ft',
                f'Location: {city.title()}' if city else 'Location: Unknown'
            ],
            'price_range': {
                'low': round(estimated_value * 0.85, 2),
                'high': round(estimated_value * 1.15, 2)
            },
            'market_analysis': 'Based on rule-based estimation using property size, type, and location.',
            'recommendation': 'Consider professional appraisal for accurate valuation'
        }


valuator = PropertyValuator()