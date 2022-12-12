// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

const int kLeftEyeId = 0;
const int kRightEyeId = 1;

uint3 _ShadingRateLevels;
uint _HalfWidth; // half of the texture width so that we do computation before shader.
uint _HalfHeight;
int2 _OffsetX; // zero centered offset and 2d because there are 2 eyes.
int2 _OffsetY;

// Writes different shading rate values depending how far the pixel is from the 0 center.
// very rough ascii drawing where 1 = 1x1 samping and 4 = 4x4 sampling.
//         4444444
//      4442222222444
//     444222111222444
//     444222111222444
//      4442222222444
//         4444444
//
uint GetShadingRateLevel(uint3 coords)
{
    int zeroCenteredCoordX = coords.x - _HalfWidth;
    int zeroCenteredCoordY = coords.y - _HalfHeight;
    float deltaX = (float)(zeroCenteredCoordX + _OffsetX[coords.z]) / (float)_HalfWidth;
    float deltaY = (float)(zeroCenteredCoordY + _OffsetY[coords.z]) / (float)_HalfHeight;
    float dist = sqrt(deltaX * deltaX + deltaY * deltaY);
    const uint slices = 3;
    uint discretizedDistance = clamp((uint)(dist * slices), 0, slices - 1);
    uint shadingRateLevel = _ShadingRateLevels[discretizedDistance];
    return shadingRateLevel;
}
