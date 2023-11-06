Shader "CustomRenderTexture/CTCopy"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _Tex("InputTex", 2D) = "white" {}
		[ToggleUI] _IsAVProInput("Is AVPro", float) = 0
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
            #pragma target 3.0

			float _IsAVProInput;
            float4      _Color;
            sampler2D   _Tex;

			#include "/Packages/com.llealloo.audiolink/Runtime/Shaders/AudioLink.cginc" 

            float4 frag(v2f_customrendertexture IN) : COLOR
            {
				float2 uv = IN.localTexcoord.xy;
				float3 col;
				if( uv.y > 1.0 - 1090.0 / 1280.0 ) // Not 1080 to add a little edge to prevent ugly bleeding.
				{
					if( _IsAVProInput )
					{
						uv.y = 1.0 - uv.y;
						col = tex2D(_Tex, uv);
						col = GammaToLinearSpace( col );
						//col.rgb = pow(col.rgb,1.4);
					}
					else
					{
						col = tex2D(_Tex, uv);
					}
				}
				else
				{
					if( uv.y < 0.1 )
					{
						col = AudioLinkData( ALPASS_THEME_COLOR0 + uint2( uv.x * 8, 0.0 ) );
					}
					else
					{
						col = 0.0;
					}
				}
				return _Color * float4( col, 1.0 );
            }
            ENDCG
            }
    }
}