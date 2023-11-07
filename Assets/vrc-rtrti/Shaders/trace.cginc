sampler2D _GeoTex;
float4 _GeoTex_TexelSize;

float max_component( float3 v )
{
	return max( max( v.x, v.y ), v.z );
}
float min_component( float3 v )
{
	return min( min( v.x, v.y ), v.z );
}

// Returns PTR, Z, STEPS
float4 CoreTrace( float3 eye, float3 dir )
{
	dir = normalize( dir );

	float2 ptr = float2( 0, 0 );
	float2 ptrhit = -1;
	float4 mincorner;
	float4 maxcorner;
	float4 truefalse;
	int i = 0;
	float minz = 1e20;
	float2 uvo = -1;
	float3 invd = 1.0 / dir;
	int tricheck = 0;

	{
		// Pick the most optimal stepping order.

		float3 dira = abs( dir );
		int axisno = (dira.x>dira.y)? ( (dira.x > dira.z)?0:2 ) : ( (dira.y > dira.z)?1:2 );
		int dire = dir[axisno]>0;
		ptr = tex2Dlod( _GeoTex, float4( (axisno * 2 + dire)*_GeoTex_TexelSize.x, 0, 0, 0) )*_GeoTex_TexelSize.xyxy;
	}
	
	[loop]
	while( i++ < 255 && ptr.y > 0 )
	{
		mincorner = tex2Dlod( _GeoTex, float4( ptr, 0, 0) );
		maxcorner = tex2Dlod( _GeoTex, float4( ptr + float2( _GeoTex_TexelSize.x*1, _GeoTex_TexelSize.y*0 ), 0, 0) );
		truefalse = tex2Dlod( _GeoTex, float4( ptr + float2( _GeoTex_TexelSize.x*0, _GeoTex_TexelSize.y*1 ), 0, 0 ) )*_GeoTex_TexelSize.xyxy;
	
		// minmaxcorner:  [ x y z ] [ radius ]
		// minmaxcorner:  [ x y z ] [ 1 if triangle, 0 otherwise ]
	
	
		//XXX XXX OPTIMIZATION OPPORTUNITY:  We can know which ones are min/max rel.
	
		// Effectively "slabs" function from: https://jcgt.org/published/0007/03/04/paper-lowres.pdf
		float3 minrel = mincorner - eye;
		float3 maxrel = maxcorner - eye;
		float3 t0 = minrel * invd;
		float3 t1 = maxrel * invd;
		float3 tmin = min(t0,t1), tmax = max(t0,t1);

		// This can be as simple as dividing the axis-value in dir by the distance to the object.
		float r = mincorner.a;
		float3 center = (minrel + maxrel)/2;
		float dr = dot( center, dir );
		
		bool hit = all(
			float3( max_component(tmin), 0, dr-r )
			<
			float3( min_component(tmax), dr+r, minz ) );

		// Does intersect, AND is it in front of us, and behind the closest hit object?
		if( hit && maxcorner.a > 0)
		{
			// Do triangle intersection. If not, set to no intersection.
			//float3 N =  tex2Dlod( _GeoTex, float4( ptr + float2( _GeoTex_TexelSize.x * 1, _GeoTex_TexelSize.y ), 0.0, 0.0 ) );
			float4 v0 = tex2Dlod( _GeoTex, float4( ptr + float2( _GeoTex_TexelSize.x * 1, _GeoTex_TexelSize.y*1 ), 0.0, 0.0 ) );
			float4 v1 = tex2Dlod( _GeoTex, float4( ptr + float2( _GeoTex_TexelSize.x * 2, _GeoTex_TexelSize.y*0 ), 0.0, 0.0 ) );
			float4 v2 = tex2Dlod( _GeoTex, float4( ptr + float2( _GeoTex_TexelSize.x * 2, _GeoTex_TexelSize.y*1 ), 0.0, 0.0 ) );
			
			// Compute t and barycentric coordinates using Moller-Trumbore
			// https://tr.inf.unibe.ch/pdf/iam-04-004.pdf
			float3 E1 = v1; // Implicitly is - v0
			float3 E2 = v2; // Implicitly is - v0
			float3 T = eye - v0;
			float3 Q = cross( T, E1 );
			float3 P = cross( dir, E2 );
			float4 tbary = 
				float4(
					1.0/dot(P,E1)*float3(
						dot( Q, E2 ),
						dot( P, T ),
						dot( Q, dir ) ), 0.0 );
			tbary.w = 1.0 - tbary.y - tbary.z;
#ifdef DEBUG_TRACE
			tricheck++;
#endif
			// Note: Normally, to not hit backfaces, we do dot( N, dir ) > 0, but
			// I think Q and dir is ok.
			if( all( tbary.xyzw >= 0 ) && tbary.x < minz && dot( Q, dir ) < 0 )
			{
				minz = tbary.x;
				ptrhit = float2( v0.a, v1.a )*_GeoTex_TexelSize.xy;
			}
		}
		ptr = hit?truefalse.xy:truefalse.zw;
	}

	return float4( ptrhit, minz,  i + tricheck * 1000 );
}


float GetTriDataFromPtr( float3 eye, float3 dir, float2 ptr, out float2 uvo, out float3 hitnorm )
{
	// Do triangle intersection. If not, set to no intersection.
	float4 v0 = tex2Dlod( _GeoTex, float4( ptr + float2( _GeoTex_TexelSize.x * 0, _GeoTex_TexelSize.y*0 ), 0.0, 0.0 ) );
	float4 v1 = tex2Dlod( _GeoTex, float4( ptr + float2( _GeoTex_TexelSize.x * 1, _GeoTex_TexelSize.y*0 ), 0.0, 0.0 ) );
	float4 v2 = tex2Dlod( _GeoTex, float4( ptr + float2( _GeoTex_TexelSize.x * 2, _GeoTex_TexelSize.y*0 ), 0.0, 0.0 ) );
	float4 n0 = tex2Dlod( _GeoTex, float4( ptr + float2( _GeoTex_TexelSize.x * 0, _GeoTex_TexelSize.y*1 ), 0.0, 0.0 ) );
	float4 n1 = tex2Dlod( _GeoTex, float4( ptr + float2( _GeoTex_TexelSize.x * 1, _GeoTex_TexelSize.y*1 ), 0.0, 0.0 ) );
	float4 n2 = tex2Dlod( _GeoTex, float4( ptr + float2( _GeoTex_TexelSize.x * 2, _GeoTex_TexelSize.y*1 ), 0.0, 0.0 ) );

	// Compute t and barycentric coordinates using Moller-Trumbore
	// https://tr.inf.unibe.ch/pdf/iam-04-004.pdf
	float3 E1 = v1; // Implicitly is - v0
	float3 E2 = v2; // Implicitly is - v0
	float3 T = eye - v0;
	float3 Q = cross( T, E1 );
	float3 P = cross( dir, E2 );
	float4 tbary = 
		float4(
			1.0/dot(P,E1)*float3(
				dot( Q, E2 ),
				dot( P, T ),
				dot( Q, dir ) ), 0.0 );
	tbary.w = 1.0 - tbary.y - tbary.z;
	
	float2 uv0 = float2( v0.w, n0.x );
	float2 uv1 = float2( v1.w, n1.x );
	float2 uv2 = float2( v2.w, n2.x );
	float2 uv = uv0 * tbary.w + uv1 * tbary.y + uv2 * tbary.z;
	hitnorm = n0.yzw * tbary.w + n1.yzw * tbary.y + n2.yzw * tbary.z;
	uvo = uv;
	return tbary.x;
}

/* Archive

Fast sphere collision code:

		// Ray-Sphere Intersection, but with normalized dir, and 0 offset.
		value.xyz = value.xyz - eye;
		float b = dot( dir, value.xyz ); // Actually would be *2, but we can algebra that out.
		float c = dot( value.xyz, value.xyz ) - value.w;
		float det = b * b - c; // a = 1; b is 1/2 "b"
		
		float radical = sqrt( det ); //Actually 1/2 radical
		float2 ts = .5*b + float2(radical,-radical);
		// T is the computed distance to sphere surface.
		
		//XXX TODO: Catch if ball is behind us. 
		// XXX TODO Check math (maybe it's right? maybe I algebrad wrong.
		det = all( ts < 0 )?-1:det;
		det = all( ts > minz)?-1:det;
*/