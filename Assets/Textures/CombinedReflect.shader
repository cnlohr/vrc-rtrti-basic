Shader "Unlit/CombinedReflect"
{
	Properties
	{
		_Tex0("Texture 0", 2D) = "white" {}
		[hdr]_Tex0Color("Texture 0 Color", Color) = (1, 1, 1, 1)
		_Tex1("Texture 1", 2D) = "white" {}
		[hdr]_Tex1Color("Texture 1 Color", Color) = (1, 1, 1, 1)
		_Tex2("Texture 2", 2D) = "white" {}
		[hdr]_Tex2Color("Texture 2 Color", Color) = (1, 1, 1, 1)
		_Tex3("Texture 3", 2D) = "white" {}
		[hdr]_Tex3Color("Texture 3 Color", Color) = (1, 1, 1, 1)
		_Tex4("Texture 4", 2D) = "white" {}
		[hdr]_Tex4Color("Texture 4 Color", Color) = (1, 1, 1, 1)
		_Tex5("Texture 5", 2D) = "white" {}
		[hdr]_Tex5Color("Texture 5 Color", Color) = (1, 1, 1, 1)
		_Tex6("Texture 6", 2D) = "white" {}
		[hdr]_Tex6Color("Texture 6 Color", Color) = (1, 1, 1, 1)
		_Tex7("Texture 7", 2D) = "white" {}
		[hdr]_Tex7Color("Texture 7 Color", Color) = (1, 1, 1, 1)
		_Tex8("Texture 8", 2D) = "white" {}
		[hdr]_Tex8Color("Texture 8 Color", Color) = (1, 1, 1, 1)
		_Tex9("Texture 9", 2D) = "white" {}
		[hdr]_Tex9Color("Texture 9 Color", Color) = (1, 1, 1, 1)
	 }

	 SubShader
	 {
		Lighting Off
		Blend One Zero

		Pass
		{
			CGPROGRAM
			#include "UnityCustomRenderTexture.cginc"
			#pragma vertex CustomRenderTextureVertexShader
			#pragma fragment frag
			#pragma target 5.0

			float4	  _Tex0Color;
			float4	  _Tex1Color;
			float4	  _Tex2Color;
			float4	  _Tex3Color;
			float4	  _Tex4Color;
			float4	  _Tex5Color;
			float4	  _Tex6Color;
			float4	  _Tex7Color;
			float4	  _Tex8Color;
			float4	  _Tex9Color;

			float4 _Tex0_ST;
			float4 _Tex1_ST;
			float4 _Tex2_ST;
			float4 _Tex3_ST;
			float4 _Tex4_ST;
			float4 _Tex5_ST;
			float4 _Tex6_ST;
			float4 _Tex7_ST;
			float4 _Tex8_ST;
			float4 _Tex9_ST;
			
			sampler2D   _Tex0;
			sampler2D   _Tex1;
			sampler2D   _Tex2;
			sampler2D   _Tex3;
			sampler2D   _Tex4;
			sampler2D   _Tex5;
			sampler2D   _Tex6;
			sampler2D   _Tex7;
			sampler2D   _Tex8;
			sampler2D   _Tex9;

			float4 frag(v2f_customrendertexture IN) : COLOR
			{
				float2 nruv = float2( IN.localTexcoord.xy * float2( 10, 1 ) );
				int select = floor( nruv.x );
				nruv = frac( nruv );
				switch( select )
				{
					case 0: return tex2D(_Tex0, TRANSFORM_TEX( nruv, _Tex0 ) )*_Tex0Color;
					case 1: return tex2D(_Tex1, TRANSFORM_TEX( nruv, _Tex1 ) )*_Tex1Color;
					case 2: return tex2D(_Tex2, TRANSFORM_TEX( nruv, _Tex2 ) )*_Tex2Color;
					case 3: return tex2D(_Tex3, TRANSFORM_TEX( nruv, _Tex3 ) )*_Tex3Color;
					case 4: return tex2D(_Tex4, TRANSFORM_TEX( nruv, _Tex4 ) )*_Tex4Color;
					case 5: return tex2D(_Tex5, TRANSFORM_TEX( nruv, _Tex5 ) )*_Tex5Color;
					case 6: return tex2D(_Tex6, TRANSFORM_TEX( nruv, _Tex6 ) )*_Tex6Color;
					case 7: return tex2D(_Tex7, TRANSFORM_TEX( nruv, _Tex7 ) )*_Tex7Color;
					case 8: return tex2D(_Tex8, TRANSFORM_TEX( nruv, _Tex8 ) )*_Tex8Color;
					case 9: return tex2D(_Tex9, TRANSFORM_TEX( nruv, _Tex9 ) )*_Tex9Color;
				}
				return 0;
			}
			ENDCG
			}
	}
}