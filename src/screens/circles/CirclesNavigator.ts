import type { StorePayload, ProductPayload } from '../../services/circles';

export type CirclesStackParamList = {
  CirclesList:    undefined;
  CircleDetail:   { circleId: string };
  CreateCircle:   undefined;
  ShareToCircle:  {
    circleId?: string;
    type?:     'store' | 'product';
    payload?:  StorePayload | ProductPayload;
  };
  JoinCircle: {
    circleId: string;
    token:    string;
  };
};
