Shader "Custom/RegularSurfaceAmbientAdjust"
{
    Properties
    {
        [HDR] _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Vivid( "Vividity", float ) = 1.0
        _Metallic ("Metallic", Range(0,1)) = 0.0
		_Hue( "Hue", float ) = 0.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        sampler2D _MainTex;

        struct Input
        {
            float2 uv_MainTex;
        };

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;
		float _Hue;
		float _Vivid;

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

		//https://gist.github.com/ForeverZer0/f4f3ce84fe8a58d3ab8d16feb73b3509
		float3 hueShift(float3 col, float hue) {
			const float3 k = float3(0.57735, 0.57735, 0.57735);
			float cosAngle = cos(hue);
			return float3(col * cosAngle + cross(k, col) * sin(hue) + k * dot(k, col) * (1.0 - cosAngle));
		}
        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            // Albedo comes from a texture tinted by color
			float3 c = tex2D (_MainTex, IN.uv_MainTex);
			c = hueShift( c, _Hue );
			float avg = (c.x + c.y + c.z ) / 3;
			float3 diff = c - avg;
			c = diff * _Vivid + avg;
			c *= _Color;
            o.Albedo = c.rgb;
            // Metallic and smoothness come from slider variables
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            o.Alpha = 1.0;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
